import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A single recorded take that loops continuously, stacked over the others.
class LoopLayer {
  final String id;
  final String path;
  final AudioPlayer player;
  bool playing;

  LoopLayer({
    required this.id,
    required this.path,
    required this.player,
    this.playing = true,
  });
}

/// Records microphone input and plays the takes back as looping layers, so a
/// player can build a simple multi-track loop on top of the metronome.
///
/// Recording uses [record] (`AudioRecorder`) and each completed take is handed
/// to an [AudioPlayer] (audioplayers) set to [ReleaseMode.loop].
class LoopRecorder extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final List<LoopLayer> _layers = [];

  bool _isRecording = false;
  bool _permissionGranted = false;
  String? _error;

  List<LoopLayer> get layers => List.unmodifiable(_layers);
  bool get isRecording => _isRecording;
  bool get hasPermission => _permissionGranted;
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
      await player.play(DeviceFileSource(path));
      _layers.add(LoopLayer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: path,
        player: player,
      ));
    }
    notifyListeners();
  }

  Future<void> toggleLayer(String id) async {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    final layer = _layers[index];
    if (layer.playing) {
      await layer.player.pause();
      layer.playing = false;
    } else {
      await layer.player.resume();
      layer.playing = true;
    }
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

  Future<void> clearAll() async {
    for (final layer in _layers) {
      await layer.player.stop();
      await layer.player.dispose();
    }
    _layers.clear();
    notifyListeners();
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
