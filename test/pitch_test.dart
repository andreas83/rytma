import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metro_power/engine/pitch.dart';

void main() {
  group('Pitch.noteFromFrequency', () {
    test('maps reference pitches to the right note', () {
      final a4 = Pitch.noteFromFrequency(440);
      expect(a4.name, 'A');
      expect(a4.octave, 4);
      expect(a4.cents.abs(), lessThan(0.5));
      expect(a4.inTune, isTrue);

      final c4 = Pitch.noteFromFrequency(261.63);
      expect(c4.name, 'C');
      expect(c4.octave, 4);
    });

    test('reports cents deviation when slightly sharp', () {
      final reading = Pitch.noteFromFrequency(443);
      expect(reading.name, 'A');
      expect(reading.cents, greaterThan(5));
      expect(reading.inTune, isFalse);
    });
  });

  group('Pitch.detectFrequency', () {
    test('finds the fundamental of a synthetic sine wave', () {
      const sampleRate = 44100;
      const freq = 220.0;
      final samples = Float64List(2048);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = sin(2 * pi * freq * i / sampleRate);
      }
      final detected = Pitch.detectFrequency(samples, sampleRate);
      expect(detected, isNotNull);
      expect((detected! - freq).abs(), lessThan(2.0));
    });

    test('returns null for silence', () {
      final silence = Float64List(2048);
      expect(Pitch.detectFrequency(silence, 44100), isNull);
    });
  });
}
