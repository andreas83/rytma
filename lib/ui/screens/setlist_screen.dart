import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/factory_presets.dart';
import '../../models/preset.dart';
import '../../state/metronome_controller.dart';

/// Lists built-in and saved presets for quick recall. Loading a preset applies
/// its full [MetronomeState] (tempo, meter, accents, subdivision, polyrhythm,
/// trainers).
class SetlistScreen extends StatelessWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final userPresets = controller.presets;

    return Scaffold(
      appBar: AppBar(title: const Text('Setlist')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Built-in'),
          for (final preset in FactoryPresets.all)
            _PresetTile(preset: preset),
          const _SectionHeader('My presets'),
          if (userPresets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'No saved presets yet — tap “Save as preset” on the Metronome '
                'screen to store your current setup.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final preset in userPresets)
            _PresetTile(preset: preset, onDelete: () => controller.deletePreset(preset.id)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, this.onDelete});

  final Preset preset;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MetronomeController>();
    final s = preset.state;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        title: Text(preset.name),
        subtitle: Text(
          '${s.bpm.round()} BPM · ${s.timeSignature} · ${s.subdivision.label}'
          '${s.polyEnabled ? " · poly ${s.timeSignature.beats}:${s.polyPulses}" : ""}',
        ),
        onTap: () {
          controller.loadPreset(preset);
          Navigator.of(context).pop();
        },
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
      ),
    );
  }
}
