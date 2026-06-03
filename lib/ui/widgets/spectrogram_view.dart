import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Scrolling spectrogram: time on the x-axis (newest on the right), log-spaced
/// frequency on the y-axis (low at the bottom), intensity mapped to color.
/// Optional vertical lines mark metronome bar downbeats.
class SpectrogramView extends StatelessWidget {
  const SpectrogramView({
    super.key,
    required this.columns,
    required this.markers,
    required this.showBars,
  });

  /// Each entry is one time slice: magnitudes in 0..1, low→high frequency.
  final List<Float64List> columns;
  final List<bool> markers;
  final bool showBars;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: CustomPaint(
        painter: _SpectrogramPainter(columns, markers, showBars),
        size: Size.infinite,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  _SpectrogramPainter(this.columns, this.markers, this.showBars);

  final List<Float64List> columns;
  final List<bool> markers;
  final bool showBars;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = MetroColors.heatFloor,
    );
    if (columns.isEmpty) return;

    final colWidth = size.width / columns.length;
    final paint = Paint();
    for (var x = 0; x < columns.length; x++) {
      final col = columns[x];
      final bins = col.length;
      final binHeight = size.height / bins;
      final left = x * colWidth;
      for (var b = 0; b < bins; b++) {
        // Low frequencies at the bottom.
        final top = size.height - (b + 1) * binHeight;
        paint.color = _heat(col[b]);
        canvas.drawRect(
          Rect.fromLTWH(left, top, colWidth + 0.5, binHeight + 0.5),
          paint,
        );
      }
    }

    if (showBars) {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 1.5;
      for (var x = 0; x < markers.length && x < columns.length; x++) {
        if (markers[x]) {
          final px = x * colWidth;
          canvas.drawLine(Offset(px, 0), Offset(px, size.height), line);
        }
      }
    }
  }

  /// Map 0..1 intensity to a dark→magenta→yellow heat ramp.
  Color _heat(double v) {
    if (v <= 0) return MetroColors.heatFloor;
    if (v < 0.5) {
      return Color.lerp(MetroColors.heatLow, MetroColors.heatMid, v / 0.5)!;
    }
    return Color.lerp(MetroColors.heatMid, MetroColors.heatHigh, (v - 0.5) / 0.5)!;
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) =>
      old.columns != columns ||
      old.showBars != showBars ||
      old.markers != markers;
}
