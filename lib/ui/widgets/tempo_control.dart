import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/metronome_controller.dart';

/// Large tempo display with a slider, fine +/- nudges, and a tap-tempo button.
class TempoControl extends StatelessWidget {
  const TempoControl({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final bpm = controller.state.bpm;

    return Column(
      children: [
        Text(
          bpm.round().toString(),
          style: const TextStyle(
            fontSize: 88,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        Text('beats per minute', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(
          children: [
            _NudgeButton(label: '-5', onTap: () => controller.nudgeBpm(-5)),
            _NudgeButton(label: '-1', onTap: () => controller.nudgeBpm(-1)),
            Expanded(
              child: Slider(
                value: bpm.clamp(20, 400),
                min: 20,
                max: 400,
                label: bpm.round().toString(),
                onChanged: controller.setBpm,
              ),
            ),
            _NudgeButton(label: '+1', onTap: () => controller.nudgeBpm(1)),
            _NudgeButton(label: '+5', onTap: () => controller.nudgeBpm(5)),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.tap,
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('Tap tempo'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
