import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/tick_event.dart';
import '../../models/poly_timbre.dart';
import '../../state/metronome_controller.dart';
import '../theme.dart';
import '../widgets/tempo_control.dart';

/// Polyrhythm screen: layer a second voice of N evenly spaced pulses against
/// the bar, producing a `beats : N` cross-rhythm with a color-coded grid.
class PolyrhythmScreen extends StatelessWidget {
  const PolyrhythmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final state = controller.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Polyrhythm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Text(
              '${state.timeSignature.beats} : ${state.polyPulses}',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
            ),
          ),
          Center(
            child: Text(
              state.polyEnabled ? 'Cross-rhythm active' : 'Polyrhythm off',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: RytmaSpacing.lg),
          SwitchListTile(
            title: const Text('Enable polyrhythm'),
            subtitle: const Text('Adds a second pulse layer over each bar'),
            value: state.polyEnabled,
            onChanged: controller.setPolyEnabled,
          ),
          const SizedBox(height: RytmaSpacing.sm),
          _PulseRow(
            label: 'Primary (${state.timeSignature.beats})',
            count: state.timeSignature.beats,
            voice: 0,
            color: RytmaColors.normal,
          ),
          const SizedBox(height: RytmaSpacing.md),
          _PulseRow(
            label: 'Against (${state.polyPulses})',
            count: state.polyPulses,
            voice: 1,
            color: RytmaColors.poly,
          ),
          const SizedBox(height: RytmaSpacing.lg),
          Text('Against pulses: ${state.polyPulses}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: state.polyPulses.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            label: '${state.polyPulses}',
            onChanged: (v) => controller.setPolyPulses(v.round()),
          ),
          const SizedBox(height: RytmaSpacing.sm),
          const Text('Sound', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: RytmaSpacing.xs),
          Wrap(
            spacing: RytmaSpacing.sm,
            children: [
              for (final t in PolyTimbre.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: t == state.polyTimbre,
                  onSelected: (_) => controller.setPolyTimbre(t),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 20),
              Expanded(
                child: Slider(
                  value: state.polyVolume,
                  label: '${(state.polyVolume * 100).round()}%',
                  divisions: 20,
                  onChanged: controller.setPolyVolume,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(state.polyVolume * 100).round()}%',
                    textAlign: TextAlign.end),
              ),
            ],
          ),
          const SizedBox(height: RytmaSpacing.lg),
          const TempoControl(),
        ],
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({
    required this.label,
    required this.count,
    required this.voice,
    required this.color,
  });

  final String label;
  final int count;
  final int voice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MetronomeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ValueListenableBuilder<TickEvent?>(
          valueListenable: controller.pulse,
          builder: (context, tick, _) {
            final active = (tick != null && tick.voice == voice) ? tick.beat : -1;
            return Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 70),
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == active ? color : color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
