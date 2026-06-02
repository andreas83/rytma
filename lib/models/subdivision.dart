/// How each beat is divided into evenly spaced clicks.
///
/// [pulses] is how many clicks sound per beat (1 = the beat itself, 2 =
/// eighth notes, 3 = triplets, and so on).
enum Subdivision {
  quarter('Quarter', 1, '♩'),
  eighth('Eighths', 2, '♫'),
  triplet('Triplets', 3, '³'),
  sixteenth('16ths', 4, '𝅘𝅥𝅯'),
  quintuplet('Quintuplets', 5, '⁵'),
  sextuplet('Sextuplets', 6, '⁶');

  final String label;
  final int pulses;
  final String glyph;

  const Subdivision(this.label, this.pulses, this.glyph);

  static Subdivision fromPulses(int pulses) =>
      Subdivision.values.firstWhere((s) => s.pulses == pulses,
          orElse: () => Subdivision.quarter);
}
