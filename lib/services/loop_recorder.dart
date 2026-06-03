import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import '../engine/wav.dart';

/// State of a single loop channel.
enum ChannelState { empty, recording, playing, stopped }

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

  LoopChannel(this.index)
      : volume = 1.0,
        muted = false,
        oneShot = false,
        trimStart = 0.0,
        trimEnd = 1.0,
        state = ChannelState.empty;

  bool get hasLoop => pcm != null;
}

/// A multi-channel loop station built on [flutter_soloud].
///
/// Recording streams PCM16 from the mic (`record`) into an in-memory buffer;
/// the finished take is wrapped as WAV and played through the same SoLoud
/// engine as the metronome. Because every channel is just another voice in that
/// one engine, any number of channels mix and play **simultaneously** (the old
/// audioplayers-based version could only sound one at a time due to audio-focus
/// contention).
///
/// Sample-level access also enables per-channel **trim** and length
/// **quantization** to the metronome's bar grid (the master clock), so loops
/// line up. One-shot vs. looping playback is per channel.
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
  /// tempo/meter. Used as the master grid for length quantization.
  int barSamples = 0;
  bool syncEnabled = true;
  int? _masterSamples;

  int? get recordingIndex => _recordingIndex;
  bool get isRecording => _recordingIndex != null;
  String? get error => _error;
  bool get isEmpty => channels.every((c) => c.state == ChannelState.empty);
  bool get anyPlaying => channels.any((c) => c.state == ChannelState.playing);

  void setBarSamples(int samples) => barSamples = samples;

  void setSync(bool value) {
    syncEnabled = value;
    if (!value) _masterSamples = null;
    notifyListeners();
  }

  /// Primary pad action: empty → record, recording → stop & loop,
  /// has loop → play/pause.
  Future<void> tapChannel(int index) async {
    final channel = channels[index];
    if (_recordingIndex == index) {
      await _finishRecording();
    } else if (_recordingIndex != null) {
      await _finishRecording();
      await _startRecording(index);
    } else if (channel.pcm == null) {
      await _startRecording(index);
    } else {
      await _togglePlay(index);
    }
  }

  Future<void> _startRecording(int index) async {
    if (!await _recorder.hasPermission()) {
      _error = 'Microphone permission denied';
      notifyListeners();
      return;
    }
    if (!_soloud.isInitialized) {
      await _soloud.init(sampleRate: sampleRate);
    }
    final channel = channels[index];
    await _disposeAudio(channel);
    channel.pcm = null;
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
    _recordingIndex = index;
    _error = null;
    notifyListeners();
  }

  Future<void> _finishRecording() async {
    final index = _recordingIndex;
    if (index == null) return;
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
    if (syncEnabled && barSamples > 0) {
      samples = _quantizeLength(samples);
    }
    channel.pcm = samples;
    channel.trimStart = 0;
    channel.trimEnd = 1;
    await _loadAndPlay(channel);
    notifyListeners();
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

  // --- internals ---------------------------------------------------------

  Future<void> _loadAndPlay(LoopChannel channel) async {
    await _disposeAudio(channel);
    final buffer = _trimmed(channel);
    if (buffer.length < 2) return;
    final wav = Wav.encode(buffer, sampleRate: sampleRate);
    final source = await _soloud.loadMem('loop_${channel.index}_${_loadCounter++}', wav);
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

  Int16List _quantizeLength(Int16List samples) {
    final count = samples.length;
    final int target;
    if (_masterSamples == null) {
      final bars = max(1, (count / barSamples).round());
      _masterSamples = bars * barSamples;
      target = _masterSamples!;
    } else {
      final multiple = max(1, (count / _masterSamples!).round());
      target = multiple * _masterSamples!;
    }
    if (count == target) return samples;
    if (count > target) return Int16List.fromList(samples.sublist(0, target));
    return Int16List(target)..setRange(0, count, samples);
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
