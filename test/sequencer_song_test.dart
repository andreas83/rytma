import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metro_power/models/sequencer_pattern.dart';
import 'package:metro_power/models/sequencer_song.dart';

void main() {
  group('SequencerSong', () {
    test('single() wraps one pattern as a 1-step song', () {
      final p = SequencerPattern.empty(steps: 16);
      final song = SequencerSong.single(p);
      expect(song.bank.length, 1);
      expect(song.arrangement.length, 1);
      expect(song.arrangement.first.patternIndex, 0);
      expect(song.arrangement.first.repeats, 1);
    });

    test('round-trips a multi-pattern arrangement through JSON', () {
      final song = SequencerSong(
        bank: [
          SequencerPattern.empty(steps: 16),
          SequencerPattern.empty(steps: 8),
        ],
        arrangement: const [
          ArrangementStep(patternIndex: 0, repeats: 2),
          ArrangementStep(patternIndex: 1, repeats: 4),
          ArrangementStep(patternIndex: 0, repeats: 1),
        ],
      );
      final r =
          SequencerSong.fromJson(jsonDecode(jsonEncode(song.toJson())));
      expect(r.bank.length, 2);
      expect(r.bank[1].steps, 8);
      expect(r.arrangement.length, 3);
      expect(r.arrangement[1].patternIndex, 1);
      expect(r.arrangement[1].repeats, 4);
    });

    test('fromJson drops dangling arrangement steps and never empties', () {
      final r = SequencerSong.fromJson({
        'bank': [SequencerPattern.empty().toJson()],
        'arrangement': [
          {'pattern': 0, 'repeats': 2},
          {'pattern': 5, 'repeats': 1}, // out of range → dropped
        ],
      });
      expect(r.bank.length, 1);
      expect(r.arrangement.length, 1);
      expect(r.arrangement.first.patternIndex, 0);

      final empty = SequencerSong.fromJson({});
      expect(empty.bank.length, 1);
      expect(empty.arrangement.length, 1);
    });

    test('migrates a legacy single-pattern save', () {
      // A pre-song save is just a SequencerPattern JSON.
      var p = SequencerPattern.empty(steps: 16);
      final kick = List<bool>.from(p.drums[DrumKind.kick]!)..[0] = true;
      p = p.copyWith(
        drums: Map<DrumKind, List<bool>>.from(p.drums)..[DrumKind.kick] = kick,
        root: 5,
      );
      final legacyJson = jsonEncode(p.toJson());

      final song = SequencerSong.single(
          SequencerPattern.fromJson(jsonDecode(legacyJson)));
      expect(song.bank.length, 1);
      expect(song.bank[0].root, 5);
      expect(song.bank[0].drums[DrumKind.kick]![0], isTrue);
      expect(song.arrangement.length, 1);
    });
  });
}
