import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// State of a single loop channel.
enum ChannelState { empty, recording, playing, stopped }

/// One loop channel ("track") in the loop station. Holds its own looping
/// [AudioPlayer] so several channels can play at once and independently.
class LoopChannel {
  final int index;
  AudioPlayer? player;
  String? path;
  double volume;
  bool muted;
  ChannelState state;

  LoopChannel(this.index)
      : volume = 1.0,
        muted = false,
        state = ChannelState.empty;

  bool get hasLoop => path != null && player != null;
}

/// A multi-channel looper / loop station. Each channel can be recorded into
/// independently and all recorded channels loop together over the metronome,
/// with per-channel volume / mute and play / stop, plus global play / stop /
/// clear. Only one channel records at a time (a single mic), but any number can
/// play simultaneously.
class LoopRecorder extends ChangeNotifier {
  static const int channelCount = 4;

  final AudioRecorder _recorder = AudioRecorder();
  final List<LoopChannel> channels =
      List.generate(channelCount, (i) => LoopChannel(i));

  int? _recordingIndex;
  String? _error;

  int? get recordingIndex => _recordingIndex;
  bool get isRecording => _recordingIndex != null;
  String? get error => _error;
  bool get isEmpty => channels.every((c) => c.state == ChannelState.empty);
  bool get anyPlaying => channels.any((c) => c.state == ChannelState.playing);

  /// Primary action when a channel's pad is tapped:
  /// empty → start recording, recording → stop & loop, has loop → play/pause.
  Future<void> tapChannel(int index) async {
    final channel = channels[index];
    if (_recordingIndex == index) {
      await _finishRecording();
    } else if (_recordingIndex != null) {
      await _finishRecording();
      await _startRecording(index);
    } else if (channel.state == ChannelState.empty) {
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
    final channel = channels[index];
    await _disposePlayer(channel);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/ch${index}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    channel.path = path;
    channel.state = ChannelState.recording;
    _recordingIndex = index;
    _error = null;
    notifyListeners();
  }

  Future<void> _finishRecording() async {
    final index = _recordingIndex;
    if (index == null) return;
    final channel = channels[index];
    final path = await _recorder.stop();
    _recordingIndex = null;
    if (path != null) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(channel.muted ? 0 : channel.volume);
      await player.play(DeviceFileSource(path));
      channel.player = player;
      channel.path = path;
      channel.state = ChannelState.playing;
    } else {
      channel.path = null;
      channel.state = ChannelState.empty;
    }
    notifyListeners();
  }

  Future<void> _togglePlay(int index) async {
    final channel = channels[index];
    final player = channel.player;
    if (player == null) return;
    if (channel.state == ChannelState.playing) {
      await player.pause();
      channel.state = ChannelState.stopped;
    } else {
      await player.resume();
      channel.state = ChannelState.playing;
    }
    notifyListeners();
  }

  Future<void> setVolume(int index, double volume) async {
    final channel = channels[index];
    channel.volume = volume.clamp(0.0, 1.0);
    if (!channel.muted) await channel.player?.setVolume(channel.volume);
    notifyListeners();
  }

  Future<void> toggleMute(int index) async {
    final channel = channels[index];
    channel.muted = !channel.muted;
    await channel.player?.setVolume(channel.muted ? 0 : channel.volume);
    notifyListeners();
  }

  Future<void> clearChannel(int index) async {
    final channel = channels[index];
    if (_recordingIndex == index) {
      await _recorder.stop();
      _recordingIndex = null;
    }
    await _disposePlayer(channel);
    channel.path = null;
    channel.state = ChannelState.empty;
    channel.muted = false;
    channel.volume = 1.0;
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (var i = 0; i < channelCount; i++) {
      await clearChannel(i);
    }
  }

  /// Pause every playing channel, or resume every stopped one.
  Future<void> togglePlayAll() async {
    final shouldStop = anyPlaying;
    for (final channel in channels) {
      if (channel.player == null) continue;
      if (shouldStop && channel.state == ChannelState.playing) {
        await channel.player!.pause();
        channel.state = ChannelState.stopped;
      } else if (!shouldStop && channel.state == ChannelState.stopped) {
        await channel.player!.resume();
        channel.state = ChannelState.playing;
      }
    }
    notifyListeners();
  }

  Future<void> _disposePlayer(LoopChannel channel) async {
    final player = channel.player;
    channel.player = null;
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
  }

  @override
  void dispose() {
    for (final channel in channels) {
      channel.player?.dispose();
    }
    _recorder.dispose();
    super.dispose();
  }
}
