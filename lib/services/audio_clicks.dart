import 'dart:typed_data';

import 'package:soundpool/soundpool.dart';

import '../engine/click_synth.dart';
import '../engine/tick_event.dart';

/// Low-latency playback of the synthesized click samples.
///
/// Uses [soundpool] because it is purpose-built for firing many short sounds
/// with minimal latency (ideal for a metronome). Each [ClickType] is
/// synthesized once at [init] and cached by its pool sound id.
class AudioClicks {
  Soundpool? _pool;
  final Map<ClickType, int> _soundIds = {};
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    final pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(maxStreams: 8),
    );
    _pool = pool;

    Future<void> load(ClickType type, Uint8List bytes) async {
      _soundIds[type] = await pool.loadUint8List(bytes);
    }

    await Future.wait([
      load(ClickType.strong, ClickSynth.click(frequency: 2000, volume: 1.0)),
      load(ClickType.normal, ClickSynth.click(frequency: 1500, volume: 0.85)),
      load(ClickType.weak, ClickSynth.click(frequency: 1100, volume: 0.7)),
      load(
        ClickType.sub,
        ClickSynth.click(frequency: 900, volume: 0.45, durationMs: 35),
      ),
      load(
        ClickType.polyStrong,
        ClickSynth.click(frequency: 1760, volume: 0.9, square: true),
      ),
      load(
        ClickType.polyWeak,
        ClickSynth.click(frequency: 1320, volume: 0.6, square: true),
      ),
    ]);
    _ready = true;
  }

  void play(ClickType type) {
    if (type == ClickType.mute) return;
    final pool = _pool;
    final id = _soundIds[type];
    if (pool == null || id == null) return;
    pool.play(id);
  }

  void dispose() {
    _pool?.dispose();
    _pool = null;
    _soundIds.clear();
    _ready = false;
  }
}
