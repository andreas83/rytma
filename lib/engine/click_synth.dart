import 'dart:math';
import 'dart:typed_data';

import 'wav.dart';

/// Generates short percussive click samples as in-memory 16-bit mono WAV data.
///
/// Synthesizing the clicks at runtime keeps the repo free of binary audio
/// assets and lets every accent level have a distinct pitch/timbre. Each click
/// is a sine (or square) burst shaped by a fast exponential decay envelope.
class ClickSynth {
  static const int sampleRate = 44100;

  static Uint8List click({
    required double frequency,
    double durationMs = 55,
    double volume = 0.9,
    bool square = false,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(sampleCount);
    // Time constant of the decay; smaller -> snappier click.
    final decay = durationMs * 0.45;
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final env = exp(-t * 1000 / decay);
      var wave = sin(2 * pi * frequency * t);
      if (square) wave = wave >= 0 ? 1.0 : -1.0;
      final value = (wave * env * volume * 32767).clamp(-32768.0, 32767.0);
      samples[i] = value.toInt();
    }
    return Wav.encode(samples, sampleRate: sampleRate);
  }
}
