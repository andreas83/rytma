import 'dart:math';
import 'dart:typed_data';

import '../models/sequencer_pattern.dart';
import 'pitch.dart';
import 'wav.dart';

/// Music-theory helpers shared by the synth engine and the sequencer UI.
///
/// The bass and chord tracks store *row indices*, not pitches; this maps a row
/// (plus the pattern's key + scale) to concrete MIDI notes, so the data model
/// stays pure and the theory lives in one place.
class Music {
  static const List<int> _major = [0, 2, 4, 5, 7, 9, 11];
  static const List<int> _minor = [0, 2, 3, 5, 7, 8, 10];

  /// Rows offered by the bass lane (one octave + the octave note on top).
  static const int bassRows = 8;

  /// Rows offered by the chord lane (the seven diatonic triads).
  static const int chordRows = 7;

  static const List<String> _names = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
  ];

  static List<int> intervals(SynthScale scale) =>
      scale == SynthScale.major ? _major : _minor;

  /// Name of a key root (0 == C … 11 == B).
  static String rootName(int root) => _names[root % 12];

  /// MIDI note for a bass row in the given key (row 0 == the tonic, low octave).
  static int bassMidi(int root, SynthScale scale, int row) {
    final iv = intervals(scale);
    const base = 36; // C2 region
    return base + root + iv[row % 7] + 12 * (row ~/ 7);
  }

  /// The three MIDI notes of the diatonic triad on [degree] (0 == I … 6 == VII).
  static List<int> chordMidis(int root, SynthScale scale, int degree) {
    final iv = intervals(scale);
    int semis(int idx) => iv[idx % 7] + 12 * (idx ~/ 7);
    const base = 48; // C3 region
    return [
      base + root + semis(degree),
      base + root + semis(degree + 2),
      base + root + semis(degree + 4),
    ];
  }

  /// Short label for a bass row, e.g. "C2".
  static String bassLabel(int root, SynthScale scale, int row) =>
      _midiLabel(bassMidi(root, scale, row));

  /// Roman-ish label for a chord degree (uppercase = major, lowercase = minor),
  /// based on the diatonic triad quality.
  static String chordLabel(int root, SynthScale scale, int degree) {
    const roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
    final m = chordMidis(root, scale, degree);
    final third = m[1] - m[0]; // 4 == major third, 3 == minor third
    final base = roman[degree % 7];
    return third >= 4 ? base : base.toLowerCase();
  }

  static String _midiLabel(int midi) {
    final name = _names[midi % 12];
    final octave = (midi ~/ 12) - 1;
    return '$name$octave';
  }
}

/// Waveform for the pitched (bass / chord) voices.
enum SynthWave { saw, triangle, square, sine }

/// Generates the sequencer's instrument samples as in-memory 16-bit mono WAV
/// data — drums (synthesized percussion) and pitched tones (oscillator + ADSR).
///
/// As with [ClickSynth], everything is synthesized at runtime so the repo ships
/// no binary audio assets. Samples are rendered once (per key/scale for the
/// pitched voices) and cached as SoLoud sources by the audio service.
class Synth {
  static const int sampleRate = 44100;

  // --- drums -------------------------------------------------------------

  /// Kick: a fast downward pitch sweep (~120→45 Hz) with a punchy decay.
  static Uint8List kick({double durationMs = 320, double volume = 1.0}) {
    final n = (sampleRate * durationMs / 1000).round();
    final s = Int16List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final f = 45 + 75 * exp(-t * 32);
      phase += 2 * pi * f / sampleRate;
      final env = exp(-t * 8.5);
      final click = exp(-t * 240) * 0.6; // initial transient
      final v = (sin(phase) * env + click) * volume;
      s[i] = (v.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return Wav.encode(s, sampleRate: sampleRate);
  }

  /// Snare: a noise burst layered with a short body tone.
  static Uint8List snare({double durationMs = 200, double volume = 0.9}) {
    final n = (sampleRate * durationMs / 1000).round();
    final s = Int16List(n);
    final rng = Random(1);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = exp(-t * 22);
      final noise = (rng.nextDouble() * 2 - 1) * env;
      final body = sin(2 * pi * 185 * t) * exp(-t * 28) * 0.7;
      final v = (noise * 0.8 + body) * volume;
      s[i] = (v.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return Wav.encode(s, sampleRate: sampleRate);
  }

  /// Hi-hat: very short, bright filtered noise (high-passed by differencing).
  static Uint8List hat({double durationMs = 70, double volume = 0.6}) {
    final n = (sampleRate * durationMs / 1000).round();
    final s = Int16List(n);
    final rng = Random(2);
    var prev = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = exp(-t * 70);
      final white = rng.nextDouble() * 2 - 1;
      final hp = white - prev; // crude high-pass for a metallic sheen
      prev = white;
      final v = hp * env * volume;
      s[i] = (v.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return Wav.encode(s, sampleRate: sampleRate);
  }

  /// Clap: a few quick noise bursts that smear into one another.
  static Uint8List clap({double durationMs = 200, double volume = 0.8}) {
    final n = (sampleRate * durationMs / 1000).round();
    final s = Int16List(n);
    final rng = Random(3);
    const bursts = [0.0, 0.009, 0.018, 0.028];
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var amp = 0.0;
      for (final b in bursts) {
        if (t >= b) amp += exp(-(t - b) * 130);
      }
      final v = (rng.nextDouble() * 2 - 1) * amp * 0.5 * volume;
      s[i] = (v.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return Wav.encode(s, sampleRate: sampleRate);
  }

  // --- pitched -----------------------------------------------------------

  static double _osc(SynthWave wave, double phase) {
    switch (wave) {
      case SynthWave.sine:
        return sin(phase);
      case SynthWave.square:
        return sin(phase) >= 0 ? 1.0 : -1.0;
      case SynthWave.triangle:
        return 2 / pi * asin(sin(phase));
      case SynthWave.saw:
        final p = (phase / (2 * pi)) % 1.0;
        return 2 * p - 1;
    }
  }

  /// A single pitched note with a simple attack/decay-sustain/release envelope.
  static Uint8List tone({
    required double frequency,
    double durationMs = 360,
    SynthWave wave = SynthWave.saw,
    double volume = 0.8,
    double attackMs = 6,
    double releaseMs = 90,
    double sustain = 0.65,
  }) =>
      _mix([frequency], durationMs, wave, volume, attackMs, releaseMs, sustain);

  /// A chord: several pitched voices summed (and scaled to avoid clipping).
  static Uint8List chordTone(
    List<double> frequencies, {
    double durationMs = 620,
    SynthWave wave = SynthWave.triangle,
    double volume = 0.7,
    double attackMs = 10,
    double releaseMs = 160,
    double sustain = 0.7,
  }) =>
      _mix(frequencies, durationMs, wave, volume, attackMs, releaseMs, sustain);

  static Uint8List _mix(
    List<double> freqs,
    double durationMs,
    SynthWave wave,
    double volume,
    double attackMs,
    double releaseMs,
    double sustain,
  ) {
    final n = (sampleRate * durationMs / 1000).round();
    final s = Int16List(n);
    final attack = attackMs / 1000;
    final release = releaseMs / 1000;
    final total = durationMs / 1000;
    final relStart = max(attack, total - release);
    final gain = volume / freqs.length;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      // ADSR-ish envelope: linear attack → sustain plateau → linear release.
      double env;
      if (t < attack) {
        env = t / attack;
      } else if (t < relStart) {
        env = sustain + (1 - sustain) * exp(-(t - attack) * 6);
      } else {
        final r = ((total - t) / release).clamp(0.0, 1.0);
        env = sustain * r;
      }
      var v = 0.0;
      for (final f in freqs) {
        v += _osc(wave, 2 * pi * f * t);
      }
      v *= env * gain;
      s[i] = (v.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return Wav.encode(s, sampleRate: sampleRate);
  }

  /// Convenience: render a bass note sample for a row in the given key.
  static Uint8List bass(int root, SynthScale scale, int row) =>
      tone(frequency: Pitch.frequencyForMidi(Music.bassMidi(root, scale, row)));

  /// Convenience: render a chord sample for a diatonic degree in the given key.
  static Uint8List chord(int root, SynthScale scale, int degree) => chordTone(
        Music.chordMidis(root, scale, degree)
            .map((m) => Pitch.frequencyForMidi(m))
            .toList(),
      );
}
