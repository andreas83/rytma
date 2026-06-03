import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/pitch.dart';
import '../theme.dart';

/// A chromatic tuner readout: the detected note, a cents needle (-50..+50),
/// and the measured frequency. Goes green when within ±5 cents.
class TunerGauge extends StatelessWidget {
  const TunerGauge({super.key, required this.reading});

  final NoteReading? reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final inTune = r?.inTune ?? false;
    final accent = inTune ? MetroColors.playing : MetroColors.poly;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          r?.label ?? '—',
          style: TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w800,
            height: 1,
            color: r == null ? Colors.white24 : accent,
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
              painter: _CentsDialPainter(r == null ? null : value, accent),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          r == null
              ? 'Listening…'
              : '${r.frequency.toStringAsFixed(1)} Hz · '
                  '${r.cents >= 0 ? "+" : ""}${r.cents.toStringAsFixed(0)} cents',
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ],
    );
  }
}

class _CentsDialPainter extends CustomPainter {
  _CentsDialPainter(this.cents, this.accent);

  final double? cents;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) * 0.92;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white24;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, pi, pi, false, arc);

    // Tick marks every 10 cents across ±50.
    final tick = Paint()..color = Colors.white38;
    for (var c = -50; c <= 50; c += 10) {
      final a = pi + pi * ((c + 50) / 100);
      final outer = center + Offset(cos(a), sin(a)) * radius;
      final inner = center + Offset(cos(a), sin(a)) * (radius - (c == 0 ? 18 : 10));
      tick
        ..strokeWidth = c == 0 ? 3 : 1.5
        ..color = c == 0 ? Colors.white : Colors.white38;
      canvas.drawLine(inner, outer, tick);
    }

    final value = cents;
    if (value == null) return;
    final clamped = value.clamp(-50.0, 50.0);
    final a = pi + pi * ((clamped + 50) / 100);
    final needle = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(cos(a), sin(a)) * (radius - 6), needle);
    canvas.drawCircle(center, 7, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_CentsDialPainter old) =>
      old.cents != cents || old.accent != accent;
}
