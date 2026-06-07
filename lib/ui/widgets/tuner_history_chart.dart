import 'package:flutter/material.dart';

import '../theme.dart';

/// A scrolling line chart of recent cents deviation (−[range]..+[range]) drawn
/// under the tuner gauge, so you can see at a glance whether the pitch is
/// steady, drifting sharp/flat, or settling into tune. Time runs left (older)
/// → right (now); null entries (silence) break the line into segments.
class TunerHistoryChart extends StatelessWidget {
  const TunerHistoryChart({
    super.key,
    required this.history,
    this.tolerance = 5,
    this.range = 50,
    this.height = 96,
  });

  /// Recent cents readings, oldest first; null where no pitch was detected.
  final List<double?> history;

  /// Half-width of the in-tune band, in cents (matches the gauge).
  final double tolerance;

  /// Vertical half-range of the chart, in cents.
  final double range;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HistoryPainter(
          history: history,
          tolerance: tolerance,
          range: range,
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.history,
    required this.tolerance,
    required this.range,
  });

  final List<double?> history;
  final double tolerance;
  final double range;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    final pad = 4.0; // keep ±range just inside the top/bottom edges
    double y(double cents) =>
        mid - (cents.clamp(-range, range) / range) * (mid - pad);

    final bg = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(bg, Paint()..color = const Color(0x14FFFFFF));
    canvas.save();
    canvas.clipRRect(bg);

    // In-tune band around centre.
    canvas.drawRect(
      Rect.fromLTRB(0, y(tolerance), w, y(-tolerance)),
      Paint()..color = RytmaColors.playing.withValues(alpha: 0.16),
    );

    // Gridlines; the 0-cents axis is brighter.
    for (final c in const [-50.0, -25.0, 0.0, 25.0, 50.0]) {
      if (c.abs() > range) continue;
      final yy = y(c);
      canvas.drawLine(
        Offset(0, yy),
        Offset(w, yy),
        Paint()
          ..color = c == 0 ? Colors.white30 : Colors.white12
          ..strokeWidth = c == 0 ? 1.5 : 1,
      );
    }

    // Trend line, broken at null (silence) gaps.
    final n = history.length;
    if (n >= 2) {
      final dx = w / (n - 1);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = RytmaColors.poly;
      Path? path;
      for (var i = 0; i < n; i++) {
        final c = history[i];
        if (c == null) {
          if (path != null) {
            canvas.drawPath(path, stroke);
            path = null;
          }
          continue;
        }
        final pt = Offset(i * dx, y(c));
        if (path == null) {
          path = Path()..moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      if (path != null) canvas.drawPath(path, stroke);

      // Mark the latest reading; green when within tune.
      final last = history.last;
      if (last != null) {
        final dot =
            last.abs() <= tolerance ? RytmaColors.playing : RytmaColors.poly;
        canvas.drawCircle(Offset(w, y(last)), 3.5, Paint()..color = dot);
      }
    }

    canvas.restore();
    canvas.drawRRect(
      bg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white12,
    );
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.history != history ||
      old.tolerance != tolerance ||
      old.range != range;
}
