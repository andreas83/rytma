import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metro_power/engine/pitch.dart';
import 'package:metro_power/engine/time_stretch.dart';

Int16List sine(double freq, int samples, int sampleRate) {
  final out = Int16List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = (sin(2 * pi * freq * i / sampleRate) * 12000).round();
  }
  return out;
}

void main() {
  const sampleRate = 44100;

  group('TimeStretch.wsola', () {
    test('produces approximately the target length', () {
      final input = sine(220, 22050, sampleRate); // 0.5 s
      for (final ratio in [0.8, 1.0, 1.25]) {
        final out = TimeStretch.wsola(input, ratio);
        final expected = input.length * ratio;
        expect((out.length - expected).abs() / expected, lessThan(0.05),
            reason: 'ratio $ratio produced ${out.length}');
      }
    });

    test('preserves pitch when stretching (no resample)', () {
      final input = sine(220, 22050, sampleRate);
      for (final ratio in [0.8, 1.25]) {
        final out = TimeStretch.wsola(input, ratio);
        final detected = Pitch.detectFrequency(
          Float64List.fromList(out.map((s) => s / 32768.0).toList()),
          sampleRate,
        );
        expect(detected, isNotNull, reason: 'ratio $ratio');
        expect((detected! - 220).abs(), lessThan(8),
            reason: 'ratio $ratio detected $detected Hz');
      }
    });

    test('fit() crops or pads to an exact length', () {
      final input = sine(220, 1000, sampleRate);
      expect(TimeStretch.fit(input, 500).length, 500);
      expect(TimeStretch.fit(input, 1500).length, 1500);
      expect(TimeStretch.fit(input, 1000).length, 1000);
    });
  });
}
