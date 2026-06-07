import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/tick_event.dart';
import '../../models/accent.dart';
import '../../state/metronome_controller.dart';
import '../theme.dart';

/// A row of beat cells that pulse with the primary voice and can be tapped to
/// cycle each beat's accent. Subdivision dots are drawn under each beat.
class BeatGrid extends StatelessWidget {
  const BeatGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final state = controller.state;

    return ValueListenableBuilder<TickEvent?>(
      valueListenable: controller.pulse,
      builder: (context, tick, _) {
        final activeBeat =
            (tick != null && tick.voice == 0) ? tick.beat : -1;
        final activeSub = (tick != null && tick.voice == 0) ? tick.sub : -1;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var b = 0; b < state.accents.length; b++)
              _BeatCell(
                index: b,
                accent: state.accents[b],
                subCount: state.subdivision.pulses,
                isActive: b == activeBeat,
                activeSub: b == activeBeat ? activeSub : -1,
                onTap: () => controller.cycleAccent(b),
              ),
          ],
        );
      },
    );
  }
}

class _BeatCell extends StatelessWidget {
  const _BeatCell({
    required this.index,
    required this.accent,
    required this.subCount,
    required this.isActive,
    required this.activeSub,
    required this.onTap,
  });

  final int index;
  final AccentLevel accent;
  final int subCount;
  final bool isActive;
  final int activeSub;
  final VoidCallback onTap;

  Color get _color {
    switch (accent) {
      case AccentLevel.strong:
        return RytmaColors.strong;
      case AccentLevel.normal:
        return RytmaColors.normal;
      case AccentLevel.weak:
        return RytmaColors.weak;
      case AccentLevel.mute:
        return RytmaColors.mute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lit = isActive && activeSub == 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 58,
        height: 78,
        decoration: BoxDecoration(
          color: lit ? _color : _color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(
            color: isActive ? _color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: lit ? Colors.black : Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var s = 0; s < subCount; s++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isActive && s == activeSub)
                          ? Colors.white
                          : Colors.white24,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
