import 'accent.dart';
import 'poly_timbre.dart';
import 'subdivision.dart';
import 'time_signature.dart';
import 'trainer_config.dart';

/// The complete, immutable description of what the metronome should play.
///
/// Everything the engine needs to build a bar's schedule lives here, which
/// makes the state trivial to serialize into a [Preset] and to diff for undo.
class MetronomeState {
  final double bpm;
  final TimeSignature timeSignature;
  final Subdivision subdivision;

  /// One [AccentLevel] per beat; length always equals [timeSignature.beats].
  final List<AccentLevel> accents;

  final bool polyEnabled;

  /// Number of evenly spaced pulses the polyrhythm voice plays across one bar,
  /// giving a `timeSignature.beats : polyPulses` cross-rhythm.
  final int polyPulses;

  /// Sound used for the polyrhythm voice and its loudness (0..1).
  final PolyTimbre polyTimbre;
  final double polyVolume;

  final TrainerConfig trainer;

  const MetronomeState({
    this.bpm = 120,
    this.timeSignature = const TimeSignature(4, 4),
    this.subdivision = Subdivision.quarter,
    this.accents = const [
      AccentLevel.strong,
      AccentLevel.normal,
      AccentLevel.normal,
      AccentLevel.normal,
    ],
    this.polyEnabled = false,
    this.polyPulses = 3,
    this.polyTimbre = PolyTimbre.beep,
    this.polyVolume = 0.8,
    this.trainer = const TrainerConfig(),
  });

  MetronomeState copyWith({
    double? bpm,
    TimeSignature? timeSignature,
    Subdivision? subdivision,
    List<AccentLevel>? accents,
    bool? polyEnabled,
    int? polyPulses,
    PolyTimbre? polyTimbre,
    double? polyVolume,
    TrainerConfig? trainer,
  }) {
    return MetronomeState(
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      subdivision: subdivision ?? this.subdivision,
      accents: accents ?? this.accents,
      polyEnabled: polyEnabled ?? this.polyEnabled,
      polyPulses: polyPulses ?? this.polyPulses,
      polyTimbre: polyTimbre ?? this.polyTimbre,
      polyVolume: polyVolume ?? this.polyVolume,
      trainer: trainer ?? this.trainer,
    );
  }

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'timeSignature': timeSignature.toJson(),
        'subdivision': subdivision.pulses,
        'accents': accents.map((a) => a.index).toList(),
        'polyEnabled': polyEnabled,
        'polyPulses': polyPulses,
        'polyTimbre': polyTimbre.index,
        'polyVolume': polyVolume,
        'trainer': trainer.toJson(),
      };

  factory MetronomeState.fromJson(Map<String, dynamic> json) {
    return MetronomeState(
      bpm: (json['bpm'] as num).toDouble(),
      timeSignature:
          TimeSignature.fromJson(json['timeSignature'] as Map<String, dynamic>),
      subdivision: Subdivision.fromPulses(json['subdivision'] as int),
      accents: (json['accents'] as List)
          .map((i) => AccentLevel.values[i as int])
          .toList(),
      polyEnabled: json['polyEnabled'] as bool? ?? false,
      polyPulses: json['polyPulses'] as int? ?? 3,
      polyTimbre: PolyTimbre.fromIndex(json['polyTimbre'] as int? ?? 0),
      polyVolume: (json['polyVolume'] as num?)?.toDouble() ?? 0.8,
      trainer:
          TrainerConfig.fromJson(json['trainer'] as Map<String, dynamic>? ?? {}),
    );
  }
}
