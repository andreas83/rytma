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

  /// Estimate the fundamental frequency of [samples] via autocorrelation with
  /// parabolic interpolation. Returns null when the signal is too quiet or no
  /// stable pitch is found.
  ///
  /// Intended for monophonic sources (a single sung/played note), which is the
  /// normal case when tuning an instrument.
  static double? detectFrequency(
    Float64List samples,
    int sampleRate, {
    double minHz = 50,
    double maxHz = 1500,
    double rmsThreshold = 0.01,
  }) {
    final n = samples.length;
    if (n < 2) return null;

    // Remove DC offset and measure loudness.
    var mean = 0.0;
    for (final s in samples) {
      mean += s;
    }
    mean /= n;

    var rms = 0.0;
    final centered = Float64List(n);
    for (var i = 0; i < n; i++) {
      final v = samples[i] - mean;
      centered[i] = v;
      rms += v * v;
    }
    rms = sqrt(rms / n);
    if (rms < rmsThreshold) return null;

    final maxLag = min(n - 1, (sampleRate / minHz).floor());
    final minLag = max(1, (sampleRate / maxHz).floor());
    if (maxLag <= minLag) return null;

    var bestLag = -1;
    var bestValue = 0.0;
    var previous = 0.0;
    var ascending = false;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i < n - lag; i++) {
        sum += centered[i] * centered[i + lag];
      }
      // Only consider peaks once the correlation has started rising again,
      // to skip the trivial maximum near lag 0.
      if (sum > previous) {
        ascending = true;
      } else if (ascending && sum > bestValue) {
        bestValue = sum;
        bestLag = lag - 1;
        ascending = false;
      }
      previous = sum;
    }

    if (bestLag <= 0 || bestValue <= 0) return null;

    // Parabolic interpolation around the peak for sub-sample precision.
    final refined = _interpolatePeak(centered, bestLag);
    return sampleRate / refined;
  }

  static double _interpolatePeak(Float64List x, int lag) {
    double corr(int l) {
      if (l < 1 || l >= x.length) return 0;
      var sum = 0.0;
      for (var i = 0; i < x.length - l; i++) {
        sum += x[i] * x[i + l];
      }
      return sum;
    }

    final y0 = corr(lag - 1);
    final y1 = corr(lag);
    final y2 = corr(lag + 1);
    final denom = (y0 - 2 * y1 + y2);
    if (denom == 0) return lag.toDouble();
    final shift = 0.5 * (y0 - y2) / denom;
    return lag + shift;
  }
}
