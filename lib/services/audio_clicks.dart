import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../engine/click_synth.dart';
import '../engine/tick_event.dart';

/// Low-latency playback of the synthesized click samples.
///
/// Uses [flutter_soloud], which loads PCM data directly from memory and plays
/// overlapping voices with very low latency — ideal for a metronome, and
/// actively maintained across modern Flutter/Android toolchains. Each
/// [ClickType] is synthesized once at [init] and cached as an [AudioSource].
class AudioClicks {
  final SoLoud _soloud = SoLoud.instance;
  final Map<ClickType, AudioSource> _sources = {};
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    if (!_soloud.isInitialized) {
      await _soloud.init(sampleRate: ClickSynth.sampleRate);
    }

    Future<void> load(ClickType type, Uint8List bytes) async {
      _sources[type] = await _soloud.loadMem('click_${type.name}', bytes);
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
    if (type == ClickType.mute || !_ready) return;
    final source = _sources[type];
    if (source == null) return;
    _soloud.play(source);
  }

  void dispose() {
    _sources.clear();
    _ready = false;
    if (_soloud.isInitialized) _soloud.deinit();
  }
}
