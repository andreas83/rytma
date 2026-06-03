import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metro_power/engine/pitch.dart';
import 'package:metro_power/engine/sequencer_engine.dart';
import 'package:metro_power/engine/synth.dart';
import 'package:metro_power/models/sequencer_pattern.dart';

void main() {
  group('Music theory mapping', () {
    test('bass rows map to scale tones from C2', () {
      // C major, key root 0.
      expect(Music.bassMidi(0, SynthScale.major, 0), 36); // C2
      expect(Music.bassMidi(0, SynthScale.major, 1), 38); // D2
      expect(Music.bassMidi(0, SynthScale.major, 2), 40); // E2
      expect(Music.bassMidi(0, SynthScale.major, 7), 48); // C3 (octave)
    });

    test('minor scale flattens the third', () {
      // C minor row 2 should be E♭ (39), not E (40).
      expect(Music.bassMidi(0, SynthScale.minor, 2), 39);
    });

    test('diatonic triads stack correctly in C major', () {
      // I = C major (C E G) → major third (4 semitones).
      final i = Music.chordMidis(0, SynthScale.major, 0);
      expect(i, [48, 52, 55]);
      expect(Music.chordLabel(0, SynthScale.major, 0), 'I');
      // ii = D minor (D F A) → minor third (3 semitones), lowercase label.
      final ii = Music.chordMidis(0, SynthScale.major, 1);
      expect(ii[1] - ii[0], 3);
      expect(Music.chordLabel(0, SynthScale.major, 1), 'ii');
    });

    test('frequencyForMidi matches concert pitch', () {
      expect(Pitch.frequencyForMidi(69), closeTo(440, 0.001)); // A4
      expect(Pitch.frequencyForMidi(57), closeTo(220, 0.001)); // A3
    });

    test('lead lane spans ~two octaves above the bass', () {
      // C major: lead row 0 == C4 (60), and the lane covers two octaves.
      expect(Music.leadMidi(0, SynthScale.major, 0), 60); // C4
      expect(Music.leadMidi(0, SynthScale.major, 7), 72); // C5
      expect(Music.leadMidi(0, SynthScale.major, 14), 84); // C6
      expect(Music.leadRows, 15);
    });
  });

  group('SequencerPattern', () {
    test('empty pattern has the right shape', () {
      final p = SequencerPattern.empty(steps: 16);
      expect(p.steps, 16);
      expect(p.bass.length, 16);
      expect(p.chords.length, 16);
      for (final k in DrumKind.values) {
        expect(p.drums[k]!.length, 16);
        expect(p.drums[k]!.every((b) => b == false), isTrue);
      }
    });

    test('round-trips through JSON with edits preserved', () {
      var p = SequencerPattern.empty(steps: 16);
      final kick = List<bool>.from(p.drums[DrumKind.kick]!)..[0] = true..[8] = true;
      final drums = Map<DrumKind, List<bool>>.from(p.drums)
        ..[DrumKind.kick] = kick;
      final bass = List<int?>.from(p.bass)..[4] = 2;
      final chords = List<int?>.from(p.chords)..[0] = 5;
      final lead = List<int?>.from(p.lead)..[12] = 9;
      p = p.copyWith(
        drums: drums,
        bass: bass,
        chords: chords,
        lead: lead,
        root: 7,
        scale: SynthScale.minor,
        bassWave: SynthWave.square,
        leadWave: SynthWave.saw,
        bpmOverride: 96,
      );

      final restored =
          SequencerPattern.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(restored.steps, 16);
      expect(restored.root, 7);
      expect(restored.scale, SynthScale.minor);
      expect(restored.bpmOverride, 96);
      expect(restored.drums[DrumKind.kick]![0], isTrue);
      expect(restored.drums[DrumKind.kick]![8], isTrue);
      expect(restored.drums[DrumKind.snare]!.every((b) => !b), isTrue);
      expect(restored.bass[4], 2);
      expect(restored.chords[0], 5);
      expect(restored.lead[12], 9);
      expect(restored.bassWave, SynthWave.square);
      expect(restored.leadWave, SynthWave.saw);
      expect(restored.chordWave, SynthWave.triangle); // default preserved
    });

    test('copyWith can clear the tempo override back to null', () {
      final p = SequencerPattern.empty().copyWith(bpmOverride: 120);
      expect(p.bpmOverride, 120);
      expect(p.copyWith(bpmOverride: null).bpmOverride, isNull);
      expect(p.copyWith(root: 3).bpmOverride, 120); // untouched when omitted
    });

    test('fromJson tolerates missing keys and wrong lengths', () {
      final restored = SequencerPattern.fromJson({
        'steps': 8,
        'drums': {
          'kick': [true, false], // shorter than 8 → padded
        },
      });
      expect(restored.steps, 8);
      expect(restored.drums[DrumKind.kick]!.length, 8);
      expect(restored.drums[DrumKind.kick]![0], isTrue);
      expect(restored.drums[DrumKind.kick]![7], isFalse);
      expect(restored.bass.length, 8);
      expect(restored.scale, SynthScale.major);
      expect(restored.bpmOverride, isNull);
      // Old saves (no groove keys) fall back to neutral dynamics.
      expect(restored.swing, 0);
      expect(restored.bassVelocity.length, 8);
      expect(restored.bassVelocity.every((v) => v == StepVelocity.normal),
          isTrue);
      expect(restored.drumProb[DrumKind.kick]!.length, 8);
      expect(restored.drumProb[DrumKind.kick]!.every((p) => p == 1.0), isTrue);
    });
  });

  group('Groove & dynamics', () {
    test('empty pattern has neutral dynamics', () {
      final p = SequencerPattern.empty(steps: 16);
      expect(p.swing, 0);
      expect(p.bassVelocity, everyElement(StepVelocity.normal));
      expect(p.leadProb, everyElement(1.0));
      expect(p.drumVelocity[DrumKind.snare]!.length, 16);
    });

    test('velocity gains scale ghost < normal < accent', () {
      expect(StepVelocity.ghost.gain, lessThan(StepVelocity.normal.gain));
      expect(StepVelocity.accent.gain, greaterThan(StepVelocity.normal.gain));
      expect(StepVelocity.normal.gain, 1.0);
    });

    test('groove survives a JSON round-trip', () {
      var p = SequencerPattern.empty(steps: 16);
      final bv = List<StepVelocity>.from(p.bassVelocity)..[2] = StepVelocity.accent;
      final lp = List<double>.from(p.leadProb)..[5] = 0.5;
      final kv = Map<DrumKind, List<StepVelocity>>.from(p.drumVelocity);
      kv[DrumKind.kick] = List<StepVelocity>.from(kv[DrumKind.kick]!)
        ..[0] = StepVelocity.ghost;
      p = p.copyWith(
          bassVelocity: bv, leadProb: lp, drumVelocity: kv, swing: 0.4);

      final restored =
          SequencerPattern.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(restored.swing, closeTo(0.4, 1e-9));
      expect(restored.bassVelocity[2], StepVelocity.accent);
      expect(restored.leadProb[5], 0.5);
      expect(restored.drumVelocity[DrumKind.kick]![0], StepVelocity.ghost);
    });

    test('swing is clamped to 0..0.5 on load', () {
      final restored = SequencerPattern.fromJson({'steps': 16, 'swing': 9.0});
      expect(restored.swing, 0.5);
    });
  });

  group('SequencerEngine swing', () {
    test('off-beats are delayed by swing·stepMs, staying ordered', () {
      final engine = SequencerEngine(onStep: (_) {});
      engine.configure(bpm: 120, steps: 16, stepsPerBeat: 4, swing: 0.4);
      final step = engine.stepMs; // 60000/120/4 = 125 ms
      expect(step, closeTo(125, 1e-9));
      // On-beats land on the grid; off-beats are pushed late.
      expect(engine.stepOffsetMs(0), 0);
      expect(engine.stepOffsetMs(2), closeTo(2 * step, 1e-9));
      expect(engine.stepOffsetMs(1), closeTo(step + 0.4 * step, 1e-9));
      // ...but never reach the following on-beat → ordering preserved.
      expect(engine.stepOffsetMs(1), lessThan(engine.stepOffsetMs(2)));
    });
  });
}
