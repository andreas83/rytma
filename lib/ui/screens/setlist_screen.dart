import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/factory_presets.dart';
import '../../models/preset.dart';
import '../../state/metronome_controller.dart';
import '../theme.dart';
import '../widgets/section_label.dart';

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
          const SectionLabel('Built-in',
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4)),
          for (final preset in FactoryPresets.all)
            _PresetTile(preset: preset, builtIn: true),
          const SectionLabel('My presets',
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4)),
          if (userPresets.isEmpty) const _EmptyPresets(),
          for (final preset in userPresets)
            _PresetTile(preset: preset, onDelete: () => controller.deletePreset(preset.id)),
        ],
      ),
    );
  }
}

class _EmptyPresets extends StatelessWidget {
  const _EmptyPresets();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: RytmaSpacing.md, vertical: RytmaSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(RytmaSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.bookmark_add_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: RytmaSpacing.md),
            Expanded(
              child: Text(
                'No saved presets yet — tap “Save as preset” on the Metronome '
                'screen to store your current setup.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, this.onDelete, this.builtIn = false});

  final Preset preset;
  final VoidCallback? onDelete;
  final bool builtIn;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MetronomeController>();
    final scheme = Theme.of(context).colorScheme;
    final s = preset.state;
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: RytmaSpacing.md, vertical: RytmaSpacing.xs),
      child: ListTile(
        leading: builtIn
            ? Icon(Icons.lock_outline, size: 20, color: scheme.onSurfaceVariant)
            : const Icon(Icons.bookmark, size: 20),
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
