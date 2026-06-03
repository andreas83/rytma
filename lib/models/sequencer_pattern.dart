/// The drum voices offered by the sequencer.
enum DrumKind { kick, snare, hat, clap }

/// The scale used to map the bass/chord lanes' row indices to pitches.
enum SynthScale { major, minor }

/// Allowed pattern lengths (steps), selectable by the user.
const List<int> kSequencerLengths = [8, 16, 32];

/// A serializable step-sequencer pattern: drum on/off grids plus monophonic
/// bass and chord lanes (each step holds a *row index* — the key/scale maps it
/// to a pitch), a musical key, per-track mix, and an optional tempo override.
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

  /// Bass lane: per-step row index (or null = rest).
  final List<int?> bass;

  /// Chord lane: per-step diatonic-degree row (or null = rest).
  final List<int?> chords;

  final Map<DrumKind, double> drumVol;
  final Map<DrumKind, bool> drumMute;
  final double bassVol;
  final bool bassMute;
  final double chordVol;
  final bool chordMute;

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
    required this.drumVol,
    required this.drumMute,
    required this.bassVol,
    required this.bassMute,
    required this.chordVol,
    required this.chordMute,
    required this.bpmOverride,
  });

  /// A blank pattern of [steps] length with a sensible starter beat.
  factory SequencerPattern.empty({int steps = 16}) {
    final drums = {
      for (final k in DrumKind.values) k: List<bool>.filled(steps, false),
    };
    return SequencerPattern(
      steps: steps,
      stepsPerBeat: 4,
      root: 0,
      scale: SynthScale.major,
      drums: drums,
      bass: List<int?>.filled(steps, null),
      chords: List<int?>.filled(steps, null),
      drumVol: {for (final k in DrumKind.values) k: 0.9},
      drumMute: {for (final k in DrumKind.values) k: false},
      bassVol: 0.85,
      bassMute: false,
      chordVol: 0.7,
      chordMute: false,
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
    Map<DrumKind, double>? drumVol,
    Map<DrumKind, bool>? drumMute,
    double? bassVol,
    bool? bassMute,
    double? chordVol,
    bool? chordMute,
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
      drumVol: drumVol ?? this.drumVol,
      drumMute: drumMute ?? this.drumMute,
      bassVol: bassVol ?? this.bassVol,
      bassMute: bassMute ?? this.bassMute,
      chordVol: chordVol ?? this.chordVol,
      chordMute: chordMute ?? this.chordMute,
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
        'drumVol': {for (final e in drumVol.entries) e.key.name: e.value},
        'drumMute': {for (final e in drumMute.entries) e.key.name: e.value},
        'bassVol': bassVol,
        'bassMute': bassMute,
        'chordVol': chordVol,
        'chordMute': chordMute,
        'bpmOverride': bpmOverride,
      };

  factory SequencerPattern.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as num?)?.toInt() ?? 16;
    final base = SequencerPattern.empty(steps: steps);

    List<bool> bools(Object? raw) =>
        _fit<bool>(raw, steps, false, (v) => v == true);
    List<int?> ints(Object? raw) =>
        _fit<int?>(raw, steps, null, (v) => (v as num?)?.toInt());

    final drumsJson = json['drums'] as Map<String, dynamic>? ?? const {};
    final volJson = json['drumVol'] as Map<String, dynamic>? ?? const {};
    final muteJson = json['drumMute'] as Map<String, dynamic>? ?? const {};

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
