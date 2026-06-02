import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metro_power/engine/click_synth.dart';
import 'package:metro_power/models/accent.dart';
import 'package:metro_power/models/metronome_state.dart';
import 'package:metro_power/models/subdivision.dart';
import 'package:metro_power/models/time_signature.dart';
import 'package:metro_power/models/trainer_config.dart';

void main() {
  group('MetronomeState', () {
    test('round-trips through JSON', () {
      const state = MetronomeState(
        bpm: 132,
        timeSignature: TimeSignature(7, 8),
        subdivision: Subdivision.triplet,
        accents: [
          AccentLevel.strong,
          AccentLevel.normal,
          AccentLevel.weak,
          AccentLevel.mute,
          AccentLevel.normal,
          AccentLevel.normal,
          AccentLevel.normal,
        ],
        polyEnabled: true,
        polyPulses: 5,
        trainer: TrainerConfig(tempoRampEnabled: true, rampTargetBpm: 200),
      );

      final restored = MetronomeState.fromJson(state.toJson());

      expect(restored.bpm, 132);
      expect(restored.timeSignature, const TimeSignature(7, 8));
      expect(restored.subdivision, Subdivision.triplet);
      expect(restored.accents, state.accents);
      expect(restored.polyEnabled, isTrue);
      expect(restored.polyPulses, 5);
      expect(restored.trainer.tempoRampEnabled, isTrue);
      expect(restored.trainer.rampTargetBpm, 200);
    });

    test('copyWith overrides only the given field', () {
      const state = MetronomeState();
      final next = state.copyWith(bpm: 90);
      expect(next.bpm, 90);
      expect(next.timeSignature, state.timeSignature);
    });
  });

  group('Subdivision', () {
    test('maps pulses back to the enum', () {
      expect(Subdivision.fromPulses(3), Subdivision.triplet);
      expect(Subdivision.fromPulses(99), Subdivision.quarter);
    });
  });

  group('ClickSynth', () {
    test('produces a valid mono 16-bit WAV header', () {
      final bytes = ClickSynth.click(frequency: 1000, durationMs: 20);
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

      final header = ByteData.sublistView(bytes, 0, 44);
      expect(header.getUint16(22, Endian.little), 1); // mono
      expect(header.getUint16(34, Endian.little), 16); // bits per sample
      expect(header.getUint32(24, Endian.little), ClickSynth.sampleRate);
    });
  });
}
