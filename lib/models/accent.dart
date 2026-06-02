/// The emphasis applied to a beat's downbeat click.
///
/// Cycling a beat in the UI moves through these in order; [mute] silences the
/// whole beat (including its subdivisions).
enum AccentLevel {
  mute('Mute'),
  weak('Weak'),
  normal('Normal'),
  strong('Strong');

  final String label;
  const AccentLevel(this.label);
}
