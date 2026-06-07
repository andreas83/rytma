import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rytma/engine/synth.dart';
import 'package:rytma/engine/track_export.dart';
import 'package:rytma/models/sequencer_pattern.dart';

Int16List _pcm(Uint8List wav) {
  final bd = ByteData.sublistView(wav);
  final n = (wav.length - 44) ~/ 2;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(44 + i * 2, Endian.little);
  }
  return out;
}

int _firstOnset(Int16List pcm, int threshold) {
  for (var i = 0; i < pcm.length; i++) {
    if (pcm[i].abs() > threshold) return i;
  }
  return -1;
}

SequencerPattern _withKick(SequencerPattern p, int step,
    {StepVelocity vel = StepVelocity.normal, double swing = 0}) {
  final grid = List<bool>.from(p.drums[DrumKind.kick]!)..[step] = true;
  final drums = Map<DrumKind, List<bool>>.from(p.drums)..[DrumKind.kick] = grid;
  final v = List<StepVelocity>.from(p.drumVelocity[DrumKind.kick]!)..[step] = vel;
  final dv = Map<DrumKind, List<StepVelocity>>.from(p.drumVelocity)
    ..[DrumKind.kick] = v;
  return p.copyWith(drums: drums, drumVelocity: dv, swing: swing);
}

void main() {
  group('renderPattern', () {
    test('produces a valid WAV of the expected length', () {
      final p = _withKick(SequencerPattern.empty(steps: 16), 0);
      final wav = renderPattern(p, bpm: 120, loops: 2);
      // RIFF header.
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final stepSamples = (Synth.sampleRate * 60 / 120 / 4).round();
      final total = 2 * 16 * stepSamples;
      final tail = (Synth.sampleRate * 0.8).round();
      expect(wav.length, 44 + (total + tail) * 2);
    });

    test('velocity scales the rendered amplitude', () {
      final base = SequencerPattern.empty(steps: 16);
      final accent = _pcm(renderPattern(
          _withKick(base, 0, vel: StepVelocity.accent),
          bpm: 120,
          loops: 1));
      final ghost = _pcm(renderPattern(
          _withKick(base, 0, vel: StepVelocity.ghost),
          bpm: 120,
          loops: 1));
      int peak(Int16List s) =>
          s.fold(0, (m, v) => v.abs() > m ? v.abs() : m);
      expect(peak(accent), greaterThan(peak(ghost)));
    });

    test('swing delays an off-beat hit', () {
      final base = SequencerPattern.empty(steps: 16);
      final straight =
          _pcm(renderPattern(_withKick(base, 1), bpm: 120, loops: 1));
      final swung = _pcm(renderPattern(
          _withKick(base, 1, swing: 0.5),
          bpm: 120,
          loops: 1));
      final onStraight = _firstOnset(straight, 1000);
      final onSwung = _firstOnset(swung, 1000);
      expect(onStraight, greaterThan(0));
      expect(onSwung, greaterThan(onStraight));
    });
  });
}
