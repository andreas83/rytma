/// A musical time signature, e.g. 4/4, 6/8, 7/8.
///
/// [beats] is the number of beats per bar (the upper numeral) and [unit] is
/// the note value that represents one beat (the lower numeral). Metro Power
/// treats the displayed BPM as the rate of [beats], so [unit] is primarily
/// informational / for display.
class TimeSignature {
  final int beats;
  final int unit;

  const TimeSignature(this.beats, this.unit);

  /// Common note-value denominators offered in the UI.
  static const List<int> units = [2, 4, 8, 16];

  TimeSignature copyWith({int? beats, int? unit}) =>
      TimeSignature(beats ?? this.beats, unit ?? this.unit);

  Map<String, dynamic> toJson() => {'beats': beats, 'unit': unit};

  factory TimeSignature.fromJson(Map<String, dynamic> json) =>
      TimeSignature(json['beats'] as int, json['unit'] as int);

  @override
  String toString() => '$beats/$unit';

  @override
  bool operator ==(Object other) =>
      other is TimeSignature && other.beats == beats && other.unit == unit;

  @override
  int get hashCode => Object.hash(beats, unit);
}
