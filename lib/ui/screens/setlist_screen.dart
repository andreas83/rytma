import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/metronome_controller.dart';

/// Lists saved presets for quick recall. Loading a preset applies its full
/// [MetronomeState] (tempo, meter, accents, subdivision, polyrhythm, trainers).
class SetlistScreen extends StatelessWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final presets = controller.presets;

    return Scaffold(
      appBar: AppBar(title: const Text('Setlist')),
      body: presets.isEmpty
          ? Center(
              child: Text(
                'No presets saved yet.\nSave one from the Metronome screen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              itemCount: presets.length,
              itemBuilder: (context, i) {
                final preset = presets[i];
                final s = preset.state;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(preset.name),
                    subtitle: Text(
                      '${s.bpm.round()} BPM · ${s.timeSignature} · '
                      '${s.subdivision.label}'
                      '${s.polyEnabled ? " · poly ${s.polyPulses}" : ""}',
                    ),
                    onTap: () {
                      controller.loadPreset(preset);
                      Navigator.of(context).pop();
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deletePreset(preset.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
