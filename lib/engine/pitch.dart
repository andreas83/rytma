import 'dart:math';
import 'dart:typed_data';

/// The musical interpretation of a detected frequency.
class NoteReading {
  /// Note name with sharp, e.g. "A", "C♯".
  final String name;
  final int octave;

  /// Distance from the in-tune pitch, in cents (-50..50).
  final double cents;
  final double frequency;

  const NoteReading({
    required this.name,
    required this.octave,
    required this.cents,
    required this.frequency,
  });

  /// Considered "in tune" within ±5 cents.
  bool get inTune => cents.abs() <= 5;

  String get label => '$name$octave';
}

/// Pitch helpers: frequency → note math and a monophonic pitch detector.
class Pitch {
  static const List<String> _names = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
  ];

  /// Map a frequency to the nearest note, using [a4] as the reference (Hz).
  static NoteReading noteFromFrequency(double frequency, {double a4 = 440}) {
    final midi = 69 + 12 * (log(frequency / a4) / ln2);
    final nearest = midi.round();
    final cents = (midi - nearest) * 100;
    final name = _names[nearest % 12];
    final octave = (nearest ~/ 12) - 1;
    return NoteReading(
      name: name,
      octave: octave,
      cents: cents,
      frequency: frequency,
    );
  }

  /// The frequency (Hz) of a MIDI note number, using [a4] as the reference.
  static double frequencyForMidi(num midi, {double a4 = 440}) =>
      a4 * pow(2, (midi - 69) / 12).toDouble();

  /// Estimate the fundamental frequency of [samples] using the YIN algorithm
  /// (de Cheveigné & Kawahara). Returns null when the signal is too quiet or no
  /// confident pitch is found.
  ///
  /// YIN is robust for monophonic sources (a single sung/played note), which is
  /// the normal case when tuning an instrument, and avoids the octave errors a
  /// naive autocorrelation peak-picker tends to make.
  static double? detectFrequency(
    Float64List samples,
    int sampleRate, {
    double minHz = 50,
    double maxHz = 1500,
    double rmsThreshold = 0.004,
    double yinThreshold = 0.12,
  }) {
    final n = samples.length;
    if (n < 4) return null;

    // Remove DC offset and measure loudness.
    var mean = 0.0;
    for (final s in samples) {
      mean += s;
    }
    mean /= n;

    var rms = 0.0;
    final x = Float64List(n);
    for (var i = 0; i < n; i++) {
      final v = samples[i] - mean;
      x[i] = v;
      rms += v * v;
    }
    rms = sqrt(rms / n);
    if (rms < rmsThreshold) return null;

    final halfN = n ~/ 2;
    final tauMax = min(halfN, (sampleRate / minHz).floor());
    final tauMin = max(2, (sampleRate / maxHz).floor());
    if (tauMax <= tauMin) return null;

    // 1. Difference function d(tau).
    final d = Float64List(tauMax + 1);
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var i = 0; i < halfN; i++) {
        final diff = x[i] - x[i + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }

    // 2. Cumulative mean normalized difference d'(tau).
    final dPrime = Float64List(tauMax + 1);
    dPrime[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      dPrime[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }

    // 3. Absolute threshold: first dip below the threshold, descending to its
    //    local minimum.
    var tau = -1;
    for (var t = tauMin; t <= tauMax; t++) {
      if (dPrime[t] < yinThreshold) {
        while (t + 1 <= tauMax && dPrime[t + 1] < dPrime[t]) {
          t++;
        }
        tau = t;
        break;
      }
    }

    // Fallback: global minimum of d' if nothing crossed the threshold.
    if (tau == -1) {
      var best = double.infinity;
      var bestT = -1;
      for (var t = tauMin; t <= tauMax; t++) {
        if (dPrime[t] < best) {
          best = dPrime[t];
          bestT = t;
        }
      }
      if (bestT == -1 || best > 0.6) return null; // too unclear → no pitch
      tau = bestT;
    }

    // 4. Parabolic interpolation around the chosen tau for sub-sample accuracy.
    final refined = _parabolicMin(dPrime, tau, tauMax);
    if (refined <= 0) return null;
    return sampleRate / refined;
  }

  static double _parabolicMin(Float64List d, int tau, int tauMax) {
    if (tau <= 1 || tau >= tauMax) return tau.toDouble();
    final x0 = d[tau - 1];
    final x1 = d[tau];
    final x2 = d[tau + 1];
    final denom = x0 + x2 - 2 * x1;
    if (denom == 0) return tau.toDouble();
    return tau + 0.5 * (x0 - x2) / denom;
  }
}
