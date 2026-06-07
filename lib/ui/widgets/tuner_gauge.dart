import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/pitch.dart';
import '../theme.dart';

/// A chromatic tuner readout: the detected note, a cents needle (-50..+50) with
/// a highlighted in-tune band, and the measured frequency. Goes green within
/// ±[tolerance] cents.
///
/// Every region sits in a fixed-size slot (and numbers use tabular figures) so
/// the gauge never shifts as the note/label widths change.
class TunerGauge extends StatelessWidget {
  const TunerGauge({super.key, required this.reading, this.tolerance = 5});

  final NoteReading? reading;

  /// Half-width of the "in tune" window, in cents.
  final double tolerance;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final inTune = r != null && r.cents.abs() <= tolerance;
    final accent = inTune ? RytmaColors.playing : RytmaColors.poly;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed-height, full-width slot keeps the big note centred and stops
        // the layout jumping when the label width changes (e.g. "A4"→"A♯4").
        SizedBox(
          height: 108,
          width: double.infinity,
          child: Center(
            child: Text(
              r?.label ?? '—',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w800,
                height: 1,
                color: r == null ? Colors.white24 : accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: double.infinity,
          // Glide the needle toward the target so it reads as relaxed rather
          // than jittery. Rests at center (0) when there is no signal.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (r?.cents ?? 0).clamp(-50.0, 50.0)),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (context, value, _) => CustomPaint(
              painter: _CentsDialPainter(
                cents: r == null ? null : value,
                accent: accent,
                tolerance: tolerance,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 24,
          child: Text(
            r == null
                ? 'Listening…'
                : '${r.frequency.toStringAsFixed(1)} Hz · '
                    '${r.cents >= 0 ? "+" : ""}${r.cents.toStringAsFixed(0)} cents',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _CentsDialPainter extends CustomPainter {
  _CentsDialPainter({
    required this.cents,
    required this.accent,
    required this.tolerance,
  });

  final double? cents;
  final Color accent;
  final double tolerance;

  /// Map a cents value (-50..50) to its angle on the bottom-spanning arc.
  double _angle(double c) => pi + pi * ((c.clamp(-50.0, 50.0) + 50) / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) * 0.92;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Base arc.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white24;
    canvas.drawArc(rect, pi, pi, false, arc);

    // In-tune tolerance band: a thick green wedge around centre so the player
    // can see how much room they have to still count as in tune.
    final a0 = _angle(-tolerance);
    final a1 = _angle(tolerance);
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = RytmaColors.playing.withValues(alpha: 0.30);
    canvas.drawArc(rect, a0, a1 - a0, false, band);

    // Tick marks every 10 cents across ±50.
    final tick = Paint()..color = Colors.white38;
    for (var c = -50; c <= 50; c += 10) {
      final a = _angle(c.toDouble());
      final outer = center + Offset(cos(a), sin(a)) * radius;
      final inner = center + Offset(cos(a), sin(a)) * (radius - (c == 0 ? 18 : 10));
      tick
        ..strokeWidth = c == 0 ? 3 : 1.5
        ..color = c == 0 ? Colors.white : Colors.white38;
      canvas.drawLine(inner, outer, tick);
    }

    final value = cents;
    if (value == null) return;
    final a = _angle(value);
    final needle = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(cos(a), sin(a)) * (radius - 6), needle);
    canvas.drawCircle(center, 7, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_CentsDialPainter old) =>
      old.cents != cents ||
      old.accent != accent ||
      old.tolerance != tolerance;
}
