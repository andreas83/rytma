import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../engine/click_synth.dart';
import '../engine/tick_event.dart';
import '../models/poly_timbre.dart';

/// Low-latency playback of the synthesized click samples.
///
/// Uses [flutter_soloud], which loads PCM data directly from memory and plays
/// overlapping voices with very low latency — ideal for a metronome, and
/// actively maintained across modern Flutter/Android toolchains. Each
/// [ClickType] is synthesized once at [init] and cached as an [AudioSource],
/// and every [PolyTimbre] gets its own strong/weak pair so the polyrhythm voice
/// is selectable.
class AudioClicks {
  final SoLoud _soloud = SoLoud.instance;
  final Map<ClickType, AudioSource> _sources = {};
  final Map<PolyTimbre, List<AudioSource>> _poly = {};
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
    ]);

    for (final timbre in PolyTimbre.values) {
      final strong = await _soloud.loadMem(
        'poly_${timbre.name}_s',
        ClickSynth.click(
          frequency: timbre.strongHz,
          volume: 0.95,
          square: timbre.square,
        ),
      );
      final weak = await _soloud.loadMem(
        'poly_${timbre.name}_w',
        ClickSynth.click(
          frequency: timbre.weakHz,
          volume: 0.75,
          square: timbre.square,
        ),
      );
      _poly[timbre] = [strong, weak];
    }
    _ready = true;
  }

  /// Play a primary-voice click.
  void play(ClickType type) {
    if (type == ClickType.mute || !_ready) return;
    final source = _sources[type];
    if (source == null) return;
    _soloud.play(source);
  }

  /// Play a polyrhythm-voice click with the chosen [timbre] and [volume] (0..1).
  /// Mixes independently of the primary voice, so coinciding pulses overlap
  /// cleanly rather than cutting each other off.
  void playPoly(PolyTimbre timbre, bool strong, double volume) {
    if (!_ready) return;
    final pair = _poly[timbre];
    if (pair == null) return;
    _soloud.play(pair[strong ? 0 : 1], volume: volume.clamp(0.0, 1.0));
  }

  void dispose() {
    _sources.clear();
    _poly.clear();
    _ready = false;
    if (_soloud.isInitialized) _soloud.deinit();
  }
}
