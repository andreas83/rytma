/// Configuration for the two practice trainers.
///
/// * Tempo ramp (a.k.a. "automator"): nudges the BPM toward [rampTargetBpm] by
///   [rampStepBpm] every [rampEveryBars] bars.
/// * Gap trainer (a.k.a. "coach"): plays [gapPlayBars] audible bars then
///   silences [gapMuteBars] bars so you have to keep time on your own.
class TrainerConfig {
  final bool tempoRampEnabled;
  final int rampStepBpm;
  final int rampEveryBars;
  final int rampTargetBpm;

  final bool gapEnabled;
  final int gapPlayBars;
  final int gapMuteBars;

  const TrainerConfig({
    this.tempoRampEnabled = false,
    this.rampStepBpm = 5,
    this.rampEveryBars = 4,
    this.rampTargetBpm = 180,
    this.gapEnabled = false,
    this.gapPlayBars = 2,
    this.gapMuteBars = 2,
  });

  bool get anyEnabled => tempoRampEnabled || gapEnabled;

  TrainerConfig copyWith({
    bool? tempoRampEnabled,
    int? rampStepBpm,
    int? rampEveryBars,
    int? rampTargetBpm,
    bool? gapEnabled,
    int? gapPlayBars,
    int? gapMuteBars,
  }) {
    return TrainerConfig(
      tempoRampEnabled: tempoRampEnabled ?? this.tempoRampEnabled,
      rampStepBpm: rampStepBpm ?? this.rampStepBpm,
      rampEveryBars: rampEveryBars ?? this.rampEveryBars,
      rampTargetBpm: rampTargetBpm ?? this.rampTargetBpm,
      gapEnabled: gapEnabled ?? this.gapEnabled,
      gapPlayBars: gapPlayBars ?? this.gapPlayBars,
      gapMuteBars: gapMuteBars ?? this.gapMuteBars,
    );
  }

  Map<String, dynamic> toJson() => {
        'tempoRampEnabled': tempoRampEnabled,
        'rampStepBpm': rampStepBpm,
        'rampEveryBars': rampEveryBars,
        'rampTargetBpm': rampTargetBpm,
        'gapEnabled': gapEnabled,
        'gapPlayBars': gapPlayBars,
        'gapMuteBars': gapMuteBars,
      };

  factory TrainerConfig.fromJson(Map<String, dynamic> json) => TrainerConfig(
        tempoRampEnabled: json['tempoRampEnabled'] as bool? ?? false,
        rampStepBpm: json['rampStepBpm'] as int? ?? 5,
        rampEveryBars: json['rampEveryBars'] as int? ?? 4,
        rampTargetBpm: json['rampTargetBpm'] as int? ?? 180,
        gapEnabled: json['gapEnabled'] as bool? ?? false,
        gapPlayBars: json['gapPlayBars'] as int? ?? 2,
        gapMuteBars: json['gapMuteBars'] as int? ?? 2,
      );
}
