import 'dart:math';
import 'dart:typed_data';

/// Offline time-stretching of mono 16-bit PCM using WSOLA (Waveform Similarity
/// Overlap-Add). Changes a clip's duration **without changing its pitch**, which
/// lets the looper warp an off-length take to fit an exact number of bars.
///
/// This runs once per recording (the buffers are finite and small), so a
/// straightforward pure-Dart implementation is plenty fast and needs no native
/// dependency.
class TimeStretch {
  const TimeStretch._();

  /// Stretch [input] by [ratio] (output length ≈ input.length * ratio). A ratio
  /// of 1.0 returns the input unchanged. The result is then expected to be
  /// trimmed/padded by the caller to an exact target length.
  ///
  /// [frame] is the analysis window, [synthesisHop] the output hop, and [search]
  /// the ± range (in samples) WSOLA may shift each frame to find the best
  /// waveform-similarity alignment (which is what preserves pitch/phase).
  static Int16List wsola(
    Int16List input,
    double ratio, {
    int frame = 1024,
    int synthesisHop = 512,
    int search = 256,
  }) {
    final n = input.length;
    if (ratio <= 0) return Int16List(0);
    // Too short to stretch meaningfully — fall back to a plain resample-free
    // crop/pad to the requested length.
    if (n < frame * 2 || (ratio - 1.0).abs() < 1e-3) {
      return _fit(input, max(1, (n * ratio).round()));
    }

    final analysisHop = (synthesisHop / ratio).round().clamp(1, frame);
    final window = _hann(frame);
    final outLength = max(frame, (n * ratio).round());
    final out = Float64List(outLength);
    final norm = Float64List(outLength);

    var analysis = 0; // read position of the current frame in input
    var synthesis = 0; // write position in output
    while (synthesis + frame < outLength) {
      // Overlap-add the chosen analysis frame into the output.
      for (var i = 0; i < frame; i++) {
        final s = analysis + i;
        if (s < 0 || s >= n) continue;
        final w = window[i];
        out[synthesis + i] += input[s] * w;
        norm[synthesis + i] += w;
      }

      // Where the *next* frame nominally starts, and the samples that should
      // follow what we just wrote (used as the cross-correlation template).
      final nextNominal = analysis + analysisHop;
      final templateAt = analysis + synthesisHop;
      final best = _bestOffset(input, templateAt, nextNominal, frame, search);

      analysis = nextNominal + best;
      synthesis += synthesisHop;
    }

    // Normalize the overlap-add and convert back to 16-bit.
    final result = Int16List(outLength);
    for (var i = 0; i < outLength; i++) {
      final value = norm[i] > 1e-6 ? out[i] / norm[i] : 0.0;
      result[i] = value.clamp(-32768.0, 32767.0).toInt();
    }
    return result;
  }

  /// Find the shift in [-search, search] of the candidate frame at
  /// [candidateAt] that best matches the template at [templateAt], by
  /// normalized cross-correlation. This keeps successive frames phase-aligned.
  static int _bestOffset(
    Int16List x,
    int templateAt,
    int candidateAt,
    int frame,
    int search,
  ) {
    final compare = min(frame, 256);
    var bestOffset = 0;
    var bestScore = -double.infinity;
    for (var offset = -search; offset <= search; offset++) {
      var dot = 0.0;
      var energy = 0.0;
      for (var i = 0; i < compare; i++) {
        final t = templateAt + i;
        final c = candidateAt + offset + i;
        if (t < 0 || t >= x.length || c < 0 || c >= x.length) continue;
        final cv = x[c].toDouble();
        dot += x[t] * cv;
        energy += cv * cv;
      }
      final score = energy > 0 ? dot / sqrt(energy) : 0.0;
      if (score > bestScore) {
        bestScore = score;
        bestOffset = offset;
      }
    }
    return bestOffset;
  }

  /// Crop or zero-pad [samples] to exactly [target] samples.
  static Int16List fit(Int16List samples, int target) => _fit(samples, target);

  static Int16List _fit(Int16List samples, int target) {
    if (target <= 0) return Int16List(0);
    if (samples.length == target) return samples;
    if (samples.length > target) {
      return Int16List.fromList(samples.sublist(0, target));
    }
    return Int16List(target)..setRange(0, samples.length, samples);
  }

  static Float64List _hann(int n) {
    final w = Float64List(n);
    for (var i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
    }
    return w;
  }
}
