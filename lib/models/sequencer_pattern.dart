/// The drum voices offered by the sequencer.
enum DrumKind { kick, snare, hat, clap }

/// The scale used to map the bass/chord/lead lanes' row indices to pitches.
enum SynthScale { major, minor }

/// Oscillator waveform for the pitched (bass / chord / lead) voices.
enum SynthWave { sine, triangle, saw, square }

/// Per-step dynamics: a ghost (soft), normal, or accented (loud) hit.
enum StepVelocity { ghost, normal, accent }

/// Volume multiplier each [StepVelocity] applies on top of the track volume.
extension StepVelocityGain on StepVelocity {
  double get gain => switch (this) {
        StepVelocity.ghost => 0.45,
        StepVelocity.normal => 1.0,
        StepVelocity.accent => 1.3,
      };
}

/// Allowed pattern lengths (steps), selectable by the user.
const List<int> kSequencerLengths = [8, 16, 32];

/// A serializable step-sequencer pattern: drum on/off grids plus monophonic
/// bass, chord and lead lanes (each step holds a *row index* — the key/scale
/// maps it to a pitch), a musical key, per-track mix + waveform, per-step
/// dynamics (velocity + probability), a swing amount, and an optional tempo
/// override.
///
/// Immutable; edits go through [copyWith] (the controller rebuilds the affected
/// list/map). Reads tolerantly from JSON so older saves still load.
class SequencerPattern {
  final int steps;
  final int stepsPerBeat;
  final int root; // 0..11 (C..B)
  final SynthScale scale;

  /// Per-drum on/off grids, each [steps] long.
  final Map<DrumKind, List<bool>> drums;

  /// Pitched lanes: per-step row index (or null = rest).
  final List<int?> bass;
  final List<int?> chords;
  final List<int?> lead;

  final Map<DrumKind, double> drumVol;
  final Map<DrumKind, bool> drumMute;
  final double bassVol;
  final bool bassMute;
  final double chordVol;
  final bool chordMute;
  final double leadVol;
  final bool leadMute;

  /// Per-voice oscillator waveform.
  final SynthWave bassWave;
  final SynthWave chordWave;
  final SynthWave leadWave;

  /// Per-step velocity (dynamics), each list [steps] long.
  final Map<DrumKind, List<StepVelocity>> drumVelocity;
  final List<StepVelocity> bassVelocity;
  final List<StepVelocity> chordVelocity;
  final List<StepVelocity> leadVelocity;

  /// Per-step trigger probability (0..1), each list [steps] long.
  final Map<DrumKind, List<double>> drumProb;
  final List<double> bassProb;
  final List<double> chordProb;
  final List<double> leadProb;

  /// Swing: fraction of a step the off-beats are delayed (0 = straight).
  final double swing;

  /// Tempo in BPM; null means "follow the metronome's tempo".
  final double? bpmOverride;

  const SequencerPattern({
    required this.steps,
    required this.stepsPerBeat,
    required this.root,
    required this.scale,
    required this.drums,
    required this.bass,
    required this.chords,
    required this.lead,
    required this.drumVol,
    required this.drumMute,
    required this.bassVol,
    required this.bassMute,
    required this.chordVol,
    required this.chordMute,
    required this.leadVol,
    required this.leadMute,
    required this.bassWave,
    required this.chordWave,
    required this.leadWave,
    required this.drumVelocity,
    required this.bassVelocity,
    required this.chordVelocity,
    required this.leadVelocity,
    required this.drumProb,
    required this.bassProb,
    required this.chordProb,
    required this.leadProb,
    required this.swing,
    required this.bpmOverride,
  });

  /// A blank pattern of [steps] length.
  factory SequencerPattern.empty({int steps = 16}) {
    List<StepVelocity> vel() => List.filled(steps, StepVelocity.normal);
    List<double> prob() => List.filled(steps, 1.0);
    return SequencerPattern(
      steps: steps,
      stepsPerBeat: 4,
      root: 0,
      scale: SynthScale.major,
      drums: {
        for (final k in DrumKind.values) k: List<bool>.filled(steps, false),
      },
      bass: List<int?>.filled(steps, null),
      chords: List<int?>.filled(steps, null),
      lead: List<int?>.filled(steps, null),
      drumVol: {for (final k in DrumKind.values) k: 0.9},
      drumMute: {for (final k in DrumKind.values) k: false},
      bassVol: 0.85,
      bassMute: false,
      chordVol: 0.7,
      chordMute: false,
      leadVol: 0.8,
      leadMute: false,
      bassWave: SynthWave.saw,
      chordWave: SynthWave.triangle,
      leadWave: SynthWave.square,
      drumVelocity: {for (final k in DrumKind.values) k: vel()},
      bassVelocity: vel(),
      chordVelocity: vel(),
      leadVelocity: vel(),
      drumProb: {for (final k in DrumKind.values) k: prob()},
      bassProb: prob(),
      chordProb: prob(),
      leadProb: prob(),
      swing: 0,
      bpmOverride: null,
    );
  }

  SequencerPattern copyWith({
    int? steps,
    int? stepsPerBeat,
    int? root,
    SynthScale? scale,
    Map<DrumKind, List<bool>>? drums,
    List<int?>? bass,
    List<int?>? chords,
    List<int?>? lead,
    Map<DrumKind, double>? drumVol,
    Map<DrumKind, bool>? drumMute,
    double? bassVol,
    bool? bassMute,
    double? chordVol,
    bool? chordMute,
    double? leadVol,
    bool? leadMute,
    SynthWave? bassWave,
    SynthWave? chordWave,
    SynthWave? leadWave,
    Map<DrumKind, List<StepVelocity>>? drumVelocity,
    List<StepVelocity>? bassVelocity,
    List<StepVelocity>? chordVelocity,
    List<StepVelocity>? leadVelocity,
    Map<DrumKind, List<double>>? drumProb,
    List<double>? bassProb,
    List<double>? chordProb,
    List<double>? leadProb,
    double? swing,
    Object? bpmOverride = _unset,
  }) {
    return SequencerPattern(
      steps: steps ?? this.steps,
      stepsPerBeat: stepsPerBeat ?? this.stepsPerBeat,
      root: root ?? this.root,
      scale: scale ?? this.scale,
      drums: drums ?? this.drums,
      bass: bass ?? this.bass,
      chords: chords ?? this.chords,
      lead: lead ?? this.lead,
      drumVol: drumVol ?? this.drumVol,
      drumMute: drumMute ?? this.drumMute,
      bassVol: bassVol ?? this.bassVol,
      bassMute: bassMute ?? this.bassMute,
      chordVol: chordVol ?? this.chordVol,
      chordMute: chordMute ?? this.chordMute,
      leadVol: leadVol ?? this.leadVol,
      leadMute: leadMute ?? this.leadMute,
      bassWave: bassWave ?? this.bassWave,
      chordWave: chordWave ?? this.chordWave,
      leadWave: leadWave ?? this.leadWave,
      drumVelocity: drumVelocity ?? this.drumVelocity,
      bassVelocity: bassVelocity ?? this.bassVelocity,
      chordVelocity: chordVelocity ?? this.chordVelocity,
      leadVelocity: leadVelocity ?? this.leadVelocity,
      drumProb: drumProb ?? this.drumProb,
      bassProb: bassProb ?? this.bassProb,
      chordProb: chordProb ?? this.chordProb,
      leadProb: leadProb ?? this.leadProb,
      swing: swing ?? this.swing,
      bpmOverride: bpmOverride == _unset
          ? this.bpmOverride
          : (bpmOverride as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'steps': steps,
        'stepsPerBeat': stepsPerBeat,
        'root': root,
        'scale': scale.name,
        'drums': {for (final e in drums.entries) e.key.name: e.value},
        'bass': bass,
        'chords': chords,
        'lead': lead,
        'drumVol': {for (final e in drumVol.entries) e.key.name: e.value},
        'drumMute': {for (final e in drumMute.entries) e.key.name: e.value},
        'bassVol': bassVol,
        'bassMute': bassMute,
        'chordVol': chordVol,
        'chordMute': chordMute,
        'leadVol': leadVol,
        'leadMute': leadMute,
        'bassWave': bassWave.name,
        'chordWave': chordWave.name,
        'leadWave': leadWave.name,
        'drumVelocity': {
          for (final e in drumVelocity.entries)
            e.key.name: [for (final v in e.value) v.name],
        },
        'bassVelocity': [for (final v in bassVelocity) v.name],
        'chordVelocity': [for (final v in chordVelocity) v.name],
        'leadVelocity': [for (final v in leadVelocity) v.name],
        'drumProb': {for (final e in drumProb.entries) e.key.name: e.value},
        'bassProb': bassProb,
        'chordProb': chordProb,
        'leadProb': leadProb,
        'swing': swing,
        'bpmOverride': bpmOverride,
      };

  factory SequencerPattern.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as num?)?.toInt() ?? 16;
    final base = SequencerPattern.empty(steps: steps);

    List<bool> bools(Object? raw) =>
        _fit<bool>(raw, steps, false, (v) => v == true);
    List<int?> ints(Object? raw) =>
        _fit<int?>(raw, steps, null, (v) => (v as num?)?.toInt());
    SynthWave wave(Object? raw, SynthWave fallback) => SynthWave.values
        .firstWhere((w) => w.name == raw, orElse: () => fallback);
    List<StepVelocity> vels(Object? raw) => _fit<StepVelocity>(
          raw,
          steps,
          StepVelocity.normal,
          (v) => StepVelocity.values
              .firstWhere((x) => x.name == v, orElse: () => StepVelocity.normal),
        );
    List<double> probs(Object? raw) => _fit<double>(
        raw, steps, 1.0, (v) => (v as num?)?.toDouble().clamp(0.0, 1.0) ?? 1.0);

    final drumsJson = json['drums'] as Map<String, dynamic>? ?? const {};
    final volJson = json['drumVol'] as Map<String, dynamic>? ?? const {};
    final muteJson = json['drumMute'] as Map<String, dynamic>? ?? const {};
    final dVelJson = json['drumVelocity'] as Map<String, dynamic>? ?? const {};
    final dProbJson = json['drumProb'] as Map<String, dynamic>? ?? const {};

    return SequencerPattern(
      steps: steps,
      stepsPerBeat: (json['stepsPerBeat'] as num?)?.toInt() ?? 4,
      root: ((json['root'] as num?)?.toInt() ?? 0).clamp(0, 11),
      scale: SynthScale.values.firstWhere(
        (s) => s.name == json['scale'],
        orElse: () => SynthScale.major,
      ),
      drums: {
        for (final k in DrumKind.values)
          k: drumsJson.containsKey(k.name)
              ? bools(drumsJson[k.name])
              : base.drums[k]!,
      },
      bass: json.containsKey('bass') ? ints(json['bass']) : base.bass,
      chords: json.containsKey('chords') ? ints(json['chords']) : base.chords,
      lead: json.containsKey('lead') ? ints(json['lead']) : base.lead,
      drumVol: {
        for (final k in DrumKind.values)
          k: (volJson[k.name] as num?)?.toDouble() ?? 0.9,
      },
      drumMute: {
        for (final k in DrumKind.values) k: muteJson[k.name] == true,
      },
      bassVol: (json['bassVol'] as num?)?.toDouble() ?? 0.85,
      bassMute: json['bassMute'] == true,
      chordVol: (json['chordVol'] as num?)?.toDouble() ?? 0.7,
      chordMute: json['chordMute'] == true,
      leadVol: (json['leadVol'] as num?)?.toDouble() ?? 0.8,
      leadMute: json['leadMute'] == true,
      bassWave: wave(json['bassWave'], SynthWave.saw),
      chordWave: wave(json['chordWave'], SynthWave.triangle),
      leadWave: wave(json['leadWave'], SynthWave.square),
      drumVelocity: {
        for (final k in DrumKind.values)
          k: dVelJson.containsKey(k.name)
              ? vels(dVelJson[k.name])
              : base.drumVelocity[k]!,
      },
      bassVelocity:
          json.containsKey('bassVelocity') ? vels(json['bassVelocity']) : base.bassVelocity,
      chordVelocity: json.containsKey('chordVelocity')
          ? vels(json['chordVelocity'])
          : base.chordVelocity,
      leadVelocity:
          json.containsKey('leadVelocity') ? vels(json['leadVelocity']) : base.leadVelocity,
      drumProb: {
        for (final k in DrumKind.values)
          k: dProbJson.containsKey(k.name)
              ? probs(dProbJson[k.name])
              : base.drumProb[k]!,
      },
      bassProb: json.containsKey('bassProb') ? probs(json['bassProb']) : base.bassProb,
      chordProb:
          json.containsKey('chordProb') ? probs(json['chordProb']) : base.chordProb,
      leadProb: json.containsKey('leadProb') ? probs(json['leadProb']) : base.leadProb,
      swing: ((json['swing'] as num?)?.toDouble() ?? 0).clamp(0.0, 0.5),
      bpmOverride: (json['bpmOverride'] as num?)?.toDouble(),
    );
  }

  /// Coerce a JSON list to exactly [n] elements (truncate / pad with [fill]).
  static List<T> _fit<T>(
      Object? raw, int n, T fill, T Function(Object?) map) {
    final list = raw is List ? raw : const [];
    return List<T>.generate(n, (i) => i < list.length ? map(list[i]) : fill);
  }

  static const Object _unset = Object();
}
