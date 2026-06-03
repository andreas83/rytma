import 'package:flutter/material.dart';

/// An uppercase, letter-spaced section heading in the primary color. Shared by
/// the metronome and setlist screens so headings look identical everywhere.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;

  /// Optional outer padding (the setlist insets its headers; the metronome
  /// screen spaces them with sized boxes and passes none).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    return padding == null ? label : Padding(padding: padding!, child: label);
  }
}
