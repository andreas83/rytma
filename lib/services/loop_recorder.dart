import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import '../engine/time_stretch.dart';
import '../engine/wav.dart';

/// State of a single loop channel. The `armed*` states mean the action is
/// scheduled to begin on the next metronome bar boundary.
enum ChannelState { empty, armedRecord, recording, armedStop, playing, stopped }

/// How a recorded take's length is matched to the metronome's bar grid.
enum LoopFit {
  /// Keep the raw recorded length.
  off,

  /// Crop / zero-pad to a whole number of bars.
  crop,

  /// Time-stretch (no pitch change) to a whole number of bars.
  warp,
}

/// One loop channel ("track"). Holds the recorded PCM plus its live voice in
/// the shared audio engine.
class LoopChannel {
  final int index;
  Int16List? pcm; // recorded (and length-synced) mono samples
  AudioSource? source;
  SoundHandle? handle;
  double volume;
  bool muted;
  bool oneShot;
  double trimStart; // 0..1
  double trimEnd; // 0..1
  ChannelState state;
  int startBar; // bar this loop's playback was aligned to
  int? loopBars; // length in whole bars (for drift re-sync), null if unsynced

  LoopChannel(this.index)
      : volume = 1.0,
        muted = false,
        oneShot = false,
        trimStart = 0.0,
        trimEnd = 1.0,
        state = ChannelState.empty,
        startBar = 0;

  bool get hasLoop => pcm != null;
  bool get isArmed =>
      state == ChannelState.armedRecord || state == ChannelState.armedStop;
}

/// A multi-channel loop station built on [flutter_soloud].
///
/// Recording streams PCM16 from the mic (`record`) into an in-memory buffer;
/// the finished take is wrapped as WAV and played through the same SoLoud
/// engine as the metronome, so any number of channels mix and play at once.
///
/// When the metronome is running and [quantizeStart] is on, record and playback
/// are aligned to bar boundaries via [handleBar] (the controller drives it from
/// the engine's bar callback), so loops stay phase-locked; a periodic `seek`
/// re-locks against long-run drift. [fit] matches recorded length to whole bars
/// by cropping or time-stretching ([LoopFit]).
class LoopRecorder extends ChangeNotifier {
  static const int channelCount = 4;
  static const int sampleRate = 44100;

  final SoLoud _soloud = SoLoud.instance;
  final AudioRecorder _recorder = AudioRecorder();
  final List<LoopChannel> channels =
      List.generate(channelCount, (i) => LoopChannel(i));

  StreamSubscription<Uint8List>? _recSub;
  BytesBuilder? _recBuf;
  int? _recordingIndex;
  String? _error;
  int _loadCounter = 0;

  /// Length of one metronome bar in samples; set by the UI from the current
  /// tempo/meter. The master grid for length quantization.
  int barSamples = 0;
  int? _masterSamples;

  LoopFit fit = LoopFit.crop;
  bool quantizeStart = true;
  bool transportRunning = false;

  int? get recordingIndex => _recordingIndex;
  bool get isRecording => _recordingIndex != null;
  String? get error => _error;
  bool get isEmpty => channels.every((c) => c.state == ChannelState.empty);
  bool get anyPlaying => channels.any((c) => c.state == ChannelState.playing);

  void setBarSamples(int samples) => barSamples = samples;
  void setTransportRunning(bool value) => transportRunning = value;

  void setFit(LoopFit value) {
    fit = value;
    if (value == LoopFit.off) _masterSamples = null;
    notifyListeners();
  }

  void setQuantizeStart(bool value) {
    quantizeStart = value;
    notifyListeners();
  }

  /// Primary pad action. With the transport running and [quantizeStart] on,
  /// record/stop are *armed* to fire on the next bar; otherwise they act now.
  Future<void> tapChannel(int index) async {
    final channel = channels[index];
    final arming = transportRunning && quantizeStart;
    switch (channel.state) {
      case ChannelState.empty:
        if (arming) {
          final ri = _recordingIndex;
          if (ri != null) channels[ri].state = ChannelState.armedStop;
          channel.state = ChannelState.armedRecord;
          notifyListeners();
        } else {
          if (_recordingIndex != null) await _finishMic(_recordingIndex!, 0);
          await _startMic(index, 0);
        }
      case ChannelState.recording:
        if (arming) {
          channel.state = ChannelState.armedStop;
          notifyListeners();
        } else {
          await _finishMic(index, 0);
        }
      case ChannelState.armedRecord:
        channel.state = ChannelState.empty; // cancel
        notifyListeners();
      case ChannelState.armedStop:
        channel.state = ChannelState.recording; // cancel the stop
        notifyListeners();
      case ChannelState.playing:
      case ChannelState.stopped:
        await _togglePlay(index);
    }
  }

  /// Called on every metronome bar boundary (wired from the controller). Starts
  /// armed recordings, finalizes armed stops, and re-locks drifting loops.
  Future<void> handleBar(int bar) async {
    final ri = _recordingIndex;
    if (ri != null && channels[ri].state == ChannelState.armedStop) {
      await _finishMic(ri, bar);
    }
    if (_recordingIndex == null) {
      final next =
          channels.indexWhere((c) => c.state == ChannelState.armedRecord);
      if (next >= 0) await _startMic(next, bar);
    }
    // Drift re-sync: snap each looping channel back to its start at loop
    // boundaries so it stays locked to the grid over long sessions.
    for (final channel in channels) {
      if (channel.state != ChannelState.playing ||
          channel.oneShot ||
          channel.loopBars == null ||
          channel.loopBars! <= 0) {
        continue;
      }
      final handle = channel.handle;
      if (handle != null &&
          bar > channel.startBar &&
          (bar - channel.startBar) % channel.loopBars! == 0 &&
          _soloud.getIsValidVoiceHandle(handle)) {
        _soloud.seek(handle, Duration.zero);
      }
    }
  }

  Future<void> _togglePlay(int index) async {
    final channel = channels[index];
    if (channel.pcm == null) return;
    final handle = channel.handle;
    final valid = handle != null && _soloud.getIsValidVoiceHandle(handle);
    if (channel.state == ChannelState.playing) {
      if (valid) _soloud.setPause(handle, true);
      channel.state = ChannelState.stopped;
    } else if (valid) {
      _soloud.setPause(handle, false);
      channel.state = ChannelState.playing;
    } else {
      await _loadAndPlay(channel); // voice ended (one-shot) → start again
    }
    notifyListeners();
  }

  Future<void> setVolume(int index, double volume) async {
    final channel = channels[index];
    channel.volume = volume.clamp(0.0, 1.0);
    final handle = channel.handle;
    if (!channel.muted && handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setVolume(handle, channel.volume);
    }
    notifyListeners();
  }

  Future<void> toggleMute(int index) async {
    final channel = channels[index];
    channel.muted = !channel.muted;
    final handle = channel.handle;
    if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setVolume(handle, channel.muted ? 0 : channel.volume);
    }
    notifyListeners();
  }

  Future<void> setOneShot(int index, bool value) async {
    final channel = channels[index];
    channel.oneShot = value;
    if (channel.state == ChannelState.playing) {
      await _loadAndPlay(channel); // re-arm with the new looping mode
    }
    notifyListeners();
  }

  /// Update trim handles (0..1) without reloading audio (call during a drag).
  void setTrim(int index, double start, double end) {
    final channel = channels[index];
    channel.trimStart = start.clamp(0.0, 0.98);
    channel.trimEnd = end.clamp(channel.trimStart + 0.02, 1.0);
    notifyListeners();
  }

  /// Apply the current trim by rebuilding and restarting the loop.
  Future<void> applyTrim(int index) async {
    final channel = channels[index];
    if (channel.pcm == null) return;
    await _loadAndPlay(channel);
    notifyListeners();
  }

  Future<void> clearChannel(int index) async {
    final channel = channels[index];
    if (_recordingIndex == index) {
      await _recSub?.cancel();
      _recSub = null;
      await _recorder.stop();
      _recordingIndex = null;
    }
    await _disposeAudio(channel);
    channel.pcm = null;
    channel.state = ChannelState.empty;
    channel.muted = false;
    channel.volume = 1.0;
    channel.oneShot = false;
    channel.trimStart = 0;
    channel.trimEnd = 1;
    channel.loopBars = null;
    if (isEmpty) _masterSamples = null;
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (var i = 0; i < channelCount; i++) {
      await clearChannel(i);
    }
  }

  Future<void> togglePlayAll() async {
    final shouldStop = anyPlaying;
    for (final channel in channels) {
      if (channel.pcm == null) continue;
      final handle = channel.handle;
      final valid = handle != null && _soloud.getIsValidVoiceHandle(handle);
      if (shouldStop && channel.state == ChannelState.playing) {
        if (valid) _soloud.setPause(handle, true);
        channel.state = ChannelState.stopped;
      } else if (!shouldStop && channel.state == ChannelState.stopped) {
        if (valid) {
          _soloud.setPause(handle, false);
          channel.state = ChannelState.playing;
        } else {
          await _loadAndPlay(channel);
        }
      }
    }
    notifyListeners();
  }

  // --- recording ---------------------------------------------------------

  Future<void> _startMic(int index, int startBar) async {
    if (!await _recorder.hasPermission()) {
      _error = 'Microphone permission denied';
      channels[index].state = ChannelState.empty;
      notifyListeners();
      return;
    }
    if (!_soloud.isInitialized) {
      await _soloud.init(sampleRate: sampleRate);
    }
    final channel = channels[index];
    await _disposeAudio(channel);
    channel.pcm = null;
    channel.loopBars = null;
    _recBuf = BytesBuilder();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    _recSub = stream.listen(
      (data) => _recBuf?.add(data),
      onError: (Object e) {
        _error = '$e';
        notifyListeners();
      },
    );
    channel.state = ChannelState.recording;
    channel.startBar = startBar;
    _recordingIndex = index;
    _error = null;
    notifyListeners();
  }

  Future<void> _finishMic(int index, int atBar) async {
    final channel = channels[index];
    await _recSub?.cancel();
    _recSub = null;
    await _recorder.stop();
    _recordingIndex = null;

    final bytes = _recBuf?.toBytes();
    _recBuf = null;
    if (bytes == null || bytes.length < 4) {
      channel.state = ChannelState.empty;
      notifyListeners();
      return;
    }

    var samples = _bytesToSamples(bytes);
    samples = _applyFit(samples);
    channel.pcm = samples;
    channel.trimStart = 0;
    channel.trimEnd = 1;
    channel.startBar = atBar;
    channel.loopBars =
        barSamples > 0 ? max(1, (samples.length / barSamples).round()) : null;
    await _loadAndPlay(channel);
    notifyListeners();
  }

  /// Match the recorded length to the bar grid per [fit].
  Int16List _applyFit(Int16List samples) {
    if (fit == LoopFit.off || barSamples <= 0) return samples;
    final target = _targetLength(samples.length);
    if (fit == LoopFit.warp && samples.length > 1) {
      final stretched = TimeStretch.wsola(samples, target / samples.length);
      return TimeStretch.fit(stretched, target);
    }
    return TimeStretch.fit(samples, target); // crop / pad
  }

  int _targetLength(int count) {
    if (_masterSamples == null) {
      final bars = max(1, (count / barSamples).round());
      _masterSamples = bars * barSamples;
      return _masterSamples!;
    }
    final multiple = max(1, (count / _masterSamples!).round());
    return multiple * _masterSamples!;
  }

  // --- playback ----------------------------------------------------------

  Future<void> _loadAndPlay(LoopChannel channel) async {
    await _disposeAudio(channel);
    final buffer = _trimmed(channel);
    if (buffer.length < 2) return;
    final wav = Wav.encode(buffer, sampleRate: sampleRate);
    final source =
        await _soloud.loadMem('loop_${channel.index}_${_loadCounter++}', wav);
    channel.source = source;
    channel.handle = _soloud.play(
      source,
      looping: !channel.oneShot,
      volume: channel.muted ? 0 : channel.volume,
    );
    channel.state = ChannelState.playing;
  }

  Int16List _trimmed(LoopChannel channel) {
    final src = channel.pcm!;
    var start = (channel.trimStart * src.length).floor();
    var end = (channel.trimEnd * src.length).ceil();
    start = start.clamp(0, src.length - 1);
    end = end.clamp(start + 1, src.length);
    return Int16List.sublistView(src, start, end);
  }

  Int16List _bytesToSamples(Uint8List bytes) {
    final n = bytes.lengthInBytes ~/ 2;
    final out = Int16List(n);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little);
    }
    return out;
  }

  Future<void> _disposeAudio(LoopChannel channel) async {
    final handle = channel.handle;
    channel.handle = null;
    if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      await _soloud.stop(handle);
    }
    final source = channel.source;
    channel.source = null;
    if (source != null) await _soloud.disposeSource(source);
  }

  @override
  void dispose() {
    _recSub?.cancel();
    for (final channel in channels) {
      final source = channel.source;
      if (source != null) _soloud.disposeSource(source);
    }
    _recorder.dispose();
    super.dispose();
  }
}
