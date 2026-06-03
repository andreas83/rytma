import 'sequencer_pattern.dart';

/// One entry in a song arrangement: play [patternIndex] for [repeats] loops.
class ArrangementStep {
  final int patternIndex;
  final int repeats;

  const ArrangementStep({required this.patternIndex, this.repeats = 1});

  ArrangementStep copyWith({int? patternIndex, int? repeats}) => ArrangementStep(
        patternIndex: patternIndex ?? this.patternIndex,
        repeats: repeats ?? this.repeats,
      );

  Map<String, dynamic> toJson() =>
      {'pattern': patternIndex, 'repeats': repeats};

  factory ArrangementStep.fromJson(Map<String, dynamic> json) => ArrangementStep(
        patternIndex: (json['pattern'] as num?)?.toInt() ?? 0,
        repeats: ((json['repeats'] as num?)?.toInt() ?? 1).clamp(1, 64),
      );
}

/// A song: a small **bank** of [SequencerPattern]s plus an **arrangement** that
/// chains them (with repeats) into a full track. The controller keeps the
/// bank's key / scale / waveforms / swing / tempo in sync across all patterns,
/// so switching patterns during playback never re-renders voices (no glitch).
///
/// Serializable and tolerant; an old single-pattern save migrates via
/// [SequencerSong.single].
class SequencerSong {
  static const int maxPatterns = 8;

  final List<SequencerPattern> bank;
  final List<ArrangementStep> arrangement;

  const SequencerSong({required this.bank, required this.arrangement});

  /// Wrap a lone pattern as a one-pattern, one-step song (legacy migration).
  factory SequencerSong.single(SequencerPattern p) => SequencerSong(
        bank: [p],
        arrangement: const [ArrangementStep(patternIndex: 0)],
      );

  SequencerSong copyWith({
    List<SequencerPattern>? bank,
    List<ArrangementStep>? arrangement,
  }) =>
      SequencerSong(
        bank: bank ?? this.bank,
        arrangement: arrangement ?? this.arrangement,
      );

  Map<String, dynamic> toJson() => {
        'bank': [for (final p in bank) p.toJson()],
        'arrangement': [for (final a in arrangement) a.toJson()],
      };

  factory SequencerSong.fromJson(Map<String, dynamic> json) {
    final rawBank = json['bank'];
    final bank = <SequencerPattern>[
      if (rawBank is List)
        for (final e in rawBank)
          SequencerPattern.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    if (bank.isEmpty) bank.add(SequencerPattern.empty());

    final rawArr = json['arrangement'];
    var arrangement = <ArrangementStep>[
      if (rawArr is List)
        for (final e in rawArr)
          ArrangementStep.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    // Drop steps that point past the bank; never leave an empty arrangement.
    arrangement =
        arrangement.where((a) => a.patternIndex < bank.length).toList();
    if (arrangement.isEmpty) {
      arrangement = const [ArrangementStep(patternIndex: 0)];
    }

    return SequencerSong(bank: bank, arrangement: arrangement);
  }
}
