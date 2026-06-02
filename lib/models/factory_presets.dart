import 'accent.dart';
import 'metronome_state.dart';
import 'preset.dart';
import 'subdivision.dart';
import 'time_signature.dart';

/// Built-in presets shown alongside the user's saved ones, so the setlist is
/// useful out of the box. These are read-only (cannot be deleted).
class FactoryPresets {
  const FactoryPresets._();

  /// Accent pattern with a strong downbeat and the rest normal.
  static List<AccentLevel> _downbeat(int beats) => [
        AccentLevel.strong,
        for (var i = 1; i < beats; i++) AccentLevel.normal,
      ];

  static final List<Preset> all = [
    Preset(
      id: 'fp_basic',
      name: 'Basic 4/4',
      state: MetronomeState(bpm: 120, accents: _downbeat(4)),
    ),
    Preset(
      id: 'fp_rock',
      name: 'Rock — 8ths',
      state: MetronomeState(
        bpm: 120,
        subdivision: Subdivision.eighth,
        accents: _downbeat(4),
      ),
    ),
    Preset(
      id: 'fp_ballad',
      name: 'Ballad',
      state: MetronomeState(
        bpm: 72,
        subdivision: Subdivision.eighth,
        accents: _downbeat(4),
      ),
    ),
    Preset(
      id: 'fp_shuffle',
      name: 'Shuffle — triplets',
      state: MetronomeState(
        bpm: 96,
        subdivision: Subdivision.triplet,
        accents: _downbeat(4),
      ),
    ),
    Preset(
      id: 'fp_waltz',
      name: 'Waltz 3/4',
      state: MetronomeState(
        bpm: 150,
        timeSignature: const TimeSignature(3, 4),
        accents: const [AccentLevel.strong, AccentLevel.weak, AccentLevel.weak],
      ),
    ),
    Preset(
      id: 'fp_68',
      name: 'Compound 6/8',
      state: MetronomeState(
        bpm: 120,
        timeSignature: const TimeSignature(6, 8),
        accents: const [
          AccentLevel.strong,
          AccentLevel.weak,
          AccentLevel.weak,
          AccentLevel.normal,
          AccentLevel.weak,
          AccentLevel.weak,
        ],
      ),
    ),
    Preset(
      id: 'fp_78',
      name: 'Odd 7/8 (2+2+3)',
      state: MetronomeState(
        bpm: 160,
        timeSignature: const TimeSignature(7, 8),
        accents: const [
          AccentLevel.strong,
          AccentLevel.weak,
          AccentLevel.normal,
          AccentLevel.weak,
          AccentLevel.normal,
          AccentLevel.weak,
          AccentLevel.weak,
        ],
      ),
    ),
    Preset(
      id: 'fp_54',
      name: 'Take Five 5/4',
      state: MetronomeState(
        bpm: 170,
        timeSignature: const TimeSignature(5, 4),
        accents: const [
          AccentLevel.strong,
          AccentLevel.normal,
          AccentLevel.normal,
          AccentLevel.normal,
          AccentLevel.normal,
        ],
      ),
    ),
    Preset(
      id: 'fp_poly32',
      name: 'Polyrhythm 3:2',
      state: MetronomeState(
        bpm: 100,
        timeSignature: const TimeSignature(3, 4),
        accents: [AccentLevel.strong, AccentLevel.normal, AccentLevel.normal],
        polyEnabled: true,
        polyPulses: 2,
      ),
    ),
    Preset(
      id: 'fp_poly43',
      name: 'Polyrhythm 4:3',
      state: MetronomeState(
        bpm: 100,
        accents: [
          AccentLevel.strong,
          AccentLevel.normal,
          AccentLevel.normal,
          AccentLevel.normal,
        ],
        polyEnabled: true,
        polyPulses: 3,
      ),
    ),
  ];
}
