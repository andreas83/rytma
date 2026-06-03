import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../engine/synth.dart';
import '../models/fx_settings.dart';
import '../models/sequencer_pattern.dart';

/// Low-latency playback for the sequencer's synthesized instruments.
///
/// Like [AudioClicks], samples are synthesized once (via [Synth]) and cached as
/// SoLoud [AudioSource]s, then triggered as overlapping voices. The four drum
/// sources are fixed; the pitched bass/chord/lead sources are re-rendered
/// whenever the key, scale, or a voice's waveform changes.
///
/// All synth voices are routed through one dedicated mixing [Bus] so the FX
/// rack ([applyFx]) affects the sequencer only — the metronome click and looper
/// keep playing on the engine directly. Bus filters are also web-safe (unlike
/// per-source filters). If the bus can't be created, playback falls back to the
/// engine and FX are silently disabled.
class SynthAudio {
  final SoLoud _soloud = SoLoud.instance;
  Bus? _bus;
  final Map<DrumKind, AudioSource> _drums = {};
  final List<AudioSource?> _bass = List.filled(Music.bassRows, null);
  final List<AudioSource?> _chords = List.filled(Music.chordRows, null);
  final List<AudioSource?> _lead = List.filled(Music.leadRows, null);

  int _root = 0;
  SynthScale _scale = SynthScale.major;
  SynthWave _bassWave = SynthWave.saw;
  SynthWave _chordWave = SynthWave.triangle;
  SynthWave _leadWave = SynthWave.square;
  bool _ready = false;
  int _loadCounter = 0;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    if (!_soloud.isInitialized) {
      await _soloud.init(sampleRate: Synth.sampleRate);
    }
    try {
      _bus = _soloud.createMixingBus()..playOnEngine();
    } catch (_) {
      _bus = null; // fall back to direct playback; FX disabled
    }
    _drums[DrumKind.kick] = await _soloud.loadMem('synth_kick', Synth.kick());
    _drums[DrumKind.snare] = await _soloud.loadMem('synth_snare', Synth.snare());
    _drums[DrumKind.hat] = await _soloud.loadMem('synth_hat', Synth.hat());
    _drums[DrumKind.clap] = await _soloud.loadMem('synth_clap', Synth.clap());
    await _renderPitched();
    _ready = true;
  }

  void _play(AudioSource source, double volume) {
    final v = volume.clamp(0.0, 1.0);
    final bus = _bus;
    if (bus != null) {
      bus.play(source, volume: v);
    } else {
      _soloud.play(source, volume: v);
    }
  }

  /// Re-render the pitched voices for a new key/scale/waveforms (no-op if
  /// nothing changed).
  Future<void> setVoices(
    int root,
    SynthScale scale, {
    required SynthWave bassWave,
    required SynthWave chordWave,
    required SynthWave leadWave,
  }) async {
    final changed = root != _root ||
        scale != _scale ||
        bassWave != _bassWave ||
        chordWave != _chordWave ||
        leadWave != _leadWave;
    _root = root;
    _scale = scale;
    _bassWave = bassWave;
    _chordWave = chordWave;
    _leadWave = leadWave;
    if (_ready && changed && _soloud.isInitialized) await _renderPitched();
  }

  Future<void> _renderPitched() async {
    for (var r = 0; r < _bass.length; r++) {
      final old = _bass[r];
      _bass[r] = await _soloud.loadMem('synth_bass_${_loadCounter++}',
          Synth.bass(_root, _scale, r, wave: _bassWave));
      if (old != null) await _soloud.disposeSource(old);
    }
    for (var d = 0; d < _chords.length; d++) {
      final old = _chords[d];
      _chords[d] = await _soloud.loadMem('synth_chord_${_loadCounter++}',
          Synth.chord(_root, _scale, d, wave: _chordWave));
      if (old != null) await _soloud.disposeSource(old);
    }
    for (var r = 0; r < _lead.length; r++) {
      final old = _lead[r];
      _lead[r] = await _soloud.loadMem('synth_lead_${_loadCounter++}',
          Synth.lead(_root, _scale, r, wave: _leadWave));
      if (old != null) await _soloud.disposeSource(old);
    }
  }

  void playDrum(DrumKind kind, double volume) {
    final source = _drums[kind];
    if (source != null) _play(source, volume);
  }

  void playBass(int row, double volume) => _playFrom(_bass, row, volume);
  void playChord(int degree, double volume) => _playFrom(_chords, degree, volume);
  void playLead(int row, double volume) => _playFrom(_lead, row, volume);

  void _playFrom(List<AudioSource?> bank, int index, double volume) {
    if (index < 0 || index >= bank.length) return;
    final source = bank[index];
    if (source != null) _play(source, volume);
  }

  /// Activate/deactivate and parameterize the bus filters from [fx]. Each
  /// effect is guarded so one unsupported filter never breaks the others.
  void applyFx(FxSettings fx) {
    final bus = _bus;
    if (bus == null) return;
    final f = bus.filters;

    void toggle(dynamic filter, bool on, void Function() params) {
      try {
        if (on) {
          if (!(filter.isActive as bool)) filter.activate();
          params();
        } else if (filter.isActive as bool) {
          filter.deactivate();
        }
      } catch (_) {
        // Best-effort: a platform may not support this filter.
      }
    }

    toggle(f.freeverbFilter, fx.reverbOn, () {
      f.freeverbFilter.wet().value = fx.reverbWet;
      f.freeverbFilter.roomSize().value = fx.reverbRoom;
    });
    toggle(f.echoFilter, fx.echoOn, () {
      f.echoFilter.wet().value = fx.echoWet;
      f.echoFilter.delay().value = (0.05 + fx.echoDelay * 0.7);
      f.echoFilter.decay().value = fx.echoDecay;
    });
    toggle(f.biquadFilter, fx.lpfOn, () {
      f.biquadFilter.type().value = 0; // 0 = low-pass
      // Log-map 0..1 to ~200..16000 Hz.
      f.biquadFilter.frequency().value = 200 * pow(80, fx.lpfCutoff).toDouble();
      f.biquadFilter.resonance().value = 0.1 + fx.lpfResonance * 15.9;
    });
    toggle(f.compressorFilter, fx.compOn, () {});
  }

  void dispose() {
    // The SoLoud engine is shared (clicks/looper); don't deinit it here.
    _drums.clear();
    _ready = false;
  }
}
