import 'accent.dart';
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
    this.trainer = const TrainerConfig(),
  });

  MetronomeState copyWith({
    double? bpm,
    TimeSignature? timeSignature,
    Subdivision? subdivision,
    List<AccentLevel>? accents,
    bool? polyEnabled,
    int? polyPulses,
    TrainerConfig? trainer,
  }) {
    return MetronomeState(
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      subdivision: subdivision ?? this.subdivision,
      accents: accents ?? this.accents,
      polyEnabled: polyEnabled ?? this.polyEnabled,
      polyPulses: polyPulses ?? this.polyPulses,
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
      trainer:
          TrainerConfig.fromJson(json['trainer'] as Map<String, dynamic>? ?? {}),
    );
  }
}
