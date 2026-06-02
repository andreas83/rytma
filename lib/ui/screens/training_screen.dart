import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/metronome_controller.dart';

/// Training screen exposing the two practice trainers: a tempo ramp that speeds
/// up over time and a gap trainer that periodically mutes the click.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final trainer = controller.state.trainer;

    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tempo ramp'),
                    subtitle: const Text('Gradually change tempo while you play'),
                    value: trainer.tempoRampEnabled,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(tempoRampEnabled: v)),
                  ),
                  _Stepper(
                    label: 'Increase by',
                    suffix: 'BPM',
                    value: trainer.rampStepBpm,
                    min: 1,
                    max: 30,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(rampStepBpm: v)),
                  ),
                  _Stepper(
                    label: 'Every',
                    suffix: 'bars',
                    value: trainer.rampEveryBars,
                    min: 1,
                    max: 32,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(rampEveryBars: v)),
                  ),
                  _Stepper(
                    label: 'Target',
                    suffix: 'BPM',
                    value: trainer.rampTargetBpm,
                    min: 20,
                    max: 400,
                    step: 5,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(rampTargetBpm: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gap trainer'),
                    subtitle: const Text('Mute the click to test your internal clock'),
                    value: trainer.gapEnabled,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(gapEnabled: v)),
                  ),
                  _Stepper(
                    label: 'Play',
                    suffix: 'bars',
                    value: trainer.gapPlayBars,
                    min: 1,
                    max: 16,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(gapPlayBars: v)),
                  ),
                  _Stepper(
                    label: 'Mute',
                    suffix: 'bars',
                    value: trainer.gapMuteBars,
                    min: 1,
                    max: 16,
                    onChanged: (v) =>
                        controller.setTrainer(trainer.copyWith(gapMuteBars: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Trainers run while the metronome plays.\nStart it from the bar below.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.filledTonal(
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 86,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
