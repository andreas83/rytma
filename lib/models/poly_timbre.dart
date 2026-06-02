/// Selectable sound for the polyrhythm voice, so it is easy to tell apart from
/// the primary click. Each timbre defines the strong/weak pulse frequencies and
/// whether to use a square wave (brighter, more cutting) or a sine (softer).
enum PolyTimbre {
  beep('Beep', 1760, 1320, false),
  wood('Wood block', 1150, 900, false),
  bell('Bell', 2350, 1760, false),
  cowbell('Cowbell', 820, 620, true),
  click('Click', 1500, 1500, true);

  final String label;
  final double strongHz;
  final double weakHz;
  final bool square;

  const PolyTimbre(this.label, this.strongHz, this.weakHz, this.square);

  static PolyTimbre fromIndex(int index) =>
      (index >= 0 && index < values.length) ? values[index] : PolyTimbre.beep;
}
