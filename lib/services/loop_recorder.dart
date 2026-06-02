import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A single recorded take that loops continuously, stacked over the others.
class LoopLayer {
  final String id;
  final String path;
  final AudioPlayer player;
  double volume;
  bool muted;

  LoopLayer({
    required this.id,
    required this.path,
    required this.player,
    this.volume = 1.0,
    this.muted = false,
  });
}

/// Records microphone takes and plays them back as looping layers, so a player
/// can build a simple multi-track loop over the metronome.
///
/// Recording uses [record] (`AudioRecorder`) and each completed take is handed
/// to a looping [AudioPlayer] (audioplayers). Supports the usual looper moves:
/// per-layer volume, mute, solo, undo (remove last), stop/play all, and clear.
class LoopRecorder extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final List<LoopLayer> _layers = [];

  bool _isRecording = false;
  bool _permissionGranted = false;
  bool _playing = true;
  String? _error;

  List<LoopLayer> get layers => List.unmodifiable(_layers);
  bool get isRecording => _isRecording;
  bool get hasPermission => _permissionGranted;
  bool get isPlaying => _playing;
  bool get isEmpty => _layers.isEmpty;
  String? get error => _error;

  Future<bool> ensurePermission() async {
    _permissionGranted = await _recorder.hasPermission();
    notifyListeners();
    return _permissionGranted;
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!await ensurePermission()) {
      _error = 'Microphone permission denied';
      notifyListeners();
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/loop_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    _isRecording = true;
    _error = null;
    notifyListeners();
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    _isRecording = false;
    if (path != null) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1);
      await player.play(DeviceFileSource(path));
      _playing = true;
      _layers.add(LoopLayer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: path,
        player: player,
      ));
    }
    notifyListeners();
  }

  Future<void> setVolume(String id, double volume) async {
    final layer = _find(id);
    if (layer == null) return;
    layer.volume = volume.clamp(0.0, 1.0);
    if (!layer.muted) await layer.player.setVolume(layer.volume);
    notifyListeners();
  }

  Future<void> toggleMute(String id) async {
    final layer = _find(id);
    if (layer == null) return;
    layer.muted = !layer.muted;
    await layer.player.setVolume(layer.muted ? 0 : layer.volume);
    notifyListeners();
  }

  /// Solo a layer: mute every other layer. If [id] is already the only audible
  /// layer, un-mute everything instead (toggle behaviour).
  Future<void> toggleSolo(String id) async {
    final alreadySoloed =
        _layers.every((l) => l.id == id ? !l.muted : l.muted) &&
            _layers.any((l) => l.id == id && !l.muted);
    for (final layer in _layers) {
      layer.muted = alreadySoloed ? false : layer.id != id;
      await layer.player.setVolume(layer.muted ? 0 : layer.volume);
    }
    notifyListeners();
  }

  /// Remove the most recently recorded layer.
  Future<void> undoLast() async {
    if (_layers.isEmpty) return;
    final layer = _layers.removeLast();
    await layer.player.stop();
    await layer.player.dispose();
    notifyListeners();
  }

  Future<void> removeLayer(String id) async {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    await _layers[index].player.stop();
    await _layers[index].player.dispose();
    _layers.removeAt(index);
    notifyListeners();
  }

  /// Pause or resume playback of every layer at once (keeps them in sync).
  Future<void> togglePlayAll() async {
    _playing = !_playing;
    for (final layer in _layers) {
      if (_playing) {
        await layer.player.resume();
      } else {
        await layer.player.pause();
      }
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final layer in _layers) {
      await layer.player.stop();
      await layer.player.dispose();
    }
    _layers.clear();
    _playing = true;
    notifyListeners();
  }

  LoopLayer? _find(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    return index < 0 ? null : _layers[index];
  }

  @override
  void dispose() {
    for (final layer in _layers) {
      layer.player.dispose();
    }
    _recorder.dispose();
    super.dispose();
  }
}
