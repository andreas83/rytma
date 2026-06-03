import 'package:flutter_soloud/flutter_soloud.dart';

import '../engine/synth.dart';
import '../models/sequencer_pattern.dart';

/// Low-latency playback for the sequencer's synthesized instruments.
///
/// Like [AudioClicks], samples are synthesized once (via [Synth]) and cached as
/// SoLoud [AudioSource]s, then triggered as overlapping voices. The four drum
/// sources are fixed; the pitched bass/chord sources are re-rendered whenever
/// the key or scale changes. The shared [SoLoud] engine mixes these alongside
/// the metronome clicks and looper voices.
class SynthAudio {
  final SoLoud _soloud = SoLoud.instance;
  final Map<DrumKind, AudioSource> _drums = {};
  final List<AudioSource?> _bass = List.filled(Music.bassRows, null);
  final List<AudioSource?> _chords = List.filled(Music.chordRows, null);

  int _root = 0;
  SynthScale _scale = SynthScale.major;
  bool _ready = false;
  int _loadCounter = 0;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    if (!_soloud.isInitialized) {
      await _soloud.init(sampleRate: Synth.sampleRate);
    }
    _drums[DrumKind.kick] = await _soloud.loadMem('synth_kick', Synth.kick());
    _drums[DrumKind.snare] = await _soloud.loadMem('synth_snare', Synth.snare());
    _drums[DrumKind.hat] = await _soloud.loadMem('synth_hat', Synth.hat());
    _drums[DrumKind.clap] = await _soloud.loadMem('synth_clap', Synth.clap());
    await _renderPitched();
    _ready = true;
  }

  /// Re-render the pitched voices for a new key/scale (no-op if unchanged).
  Future<void> setKey(int root, SynthScale scale) async {
    if (root == _root && scale == _scale && _ready) return;
    _root = root;
    _scale = scale;
    if (_soloud.isInitialized) await _renderPitched();
  }

  Future<void> _renderPitched() async {
    for (var r = 0; r < _bass.length; r++) {
      final old = _bass[r];
      _bass[r] = await _soloud.loadMem(
          'synth_bass_${_loadCounter++}', Synth.bass(_root, _scale, r));
      if (old != null) await _soloud.disposeSource(old);
    }
    for (var d = 0; d < _chords.length; d++) {
      final old = _chords[d];
      _chords[d] = await _soloud.loadMem(
          'synth_chord_${_loadCounter++}', Synth.chord(_root, _scale, d));
      if (old != null) await _soloud.disposeSource(old);
    }
  }

  void playDrum(DrumKind kind, double volume) {
    final source = _drums[kind];
    if (source == null) return;
    _soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  void playBass(int row, double volume) {
    if (row < 0 || row >= _bass.length) return;
    final source = _bass[row];
    if (source != null) _soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  void playChord(int degree, double volume) {
    if (degree < 0 || degree >= _chords.length) return;
    final source = _chords[degree];
    if (source != null) _soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  void dispose() {
    // The SoLoud engine is shared (clicks/looper); don't deinit it here.
    _drums.clear();
    _ready = false;
  }
}
