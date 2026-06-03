import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/metronome_controller.dart';
import '../theme.dart';

/// Persistent play/stop control shown above the navigation bar, with a compact
/// readout of the current tempo and meter.
class TransportBar extends StatelessWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final state = controller.state;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: MetroColors.surfaceBar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: controller.isInitialized ? controller.toggle : null,
              icon: Icon(controller.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(controller.isPlaying ? 'Stop' : 'Start'),
              style: FilledButton.styleFrom(
                backgroundColor: controller.isPlaying ? scheme.error : scheme.primary,
                minimumSize: const Size(120, 48),
              ),
            ),
            const Spacer(),
            Text(
              '${state.bpm.round()} BPM',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 16),
            Text(
              '${state.timeSignature}',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
