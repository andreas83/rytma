/// The kind of click a tick produces. Determines which synthesized sample the
/// audio service plays and how the beat grid highlights it.
enum ClickType {
  strong,
  normal,
  weak,
  sub,
  polyStrong,
  polyWeak,

  /// A scheduled position that should not make a sound (muted beat or gap).
  mute,
}

/// A single scheduled click within one bar loop.
class TickEvent {
  /// Offset from the start of the current bar, in milliseconds.
  final double timeMs;

  final ClickType type;

  /// 0 = primary voice, 1 = polyrhythm voice.
  final int voice;

  /// Beat index within the bar (for the primary voice) or pulse index (poly).
  final int beat;

  /// Subdivision index within the beat (0 == the beat itself).
  final int sub;

  const TickEvent({
    required this.timeMs,
    required this.type,
    required this.voice,
    required this.beat,
    required this.sub,
  });

  bool get isPoly => voice == 1;
  bool get isDownbeat => voice == 0 && sub == 0;
}
