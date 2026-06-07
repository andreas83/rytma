import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_signature.dart';
import '../../state/metronome_controller.dart';
import '../theme.dart';
import '../widgets/beat_grid.dart';
import '../widgets/section_label.dart';
import '../widgets/subdivision_picker.dart';
import '../widgets/tempo_control.dart';
import 'setlist_screen.dart';
import 'settings_screen.dart';

/// Main metronome screen: tempo, meter, accents and subdivisions.
class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final state = controller.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rytma'),
        actions: [
          IconButton(
            tooltip: 'Setlist',
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SetlistScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const TempoControl(),
          const SizedBox(height: RytmaSpacing.xl),
          const SectionLabel('Meter & accents'),
          const SizedBox(height: RytmaSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => controller.setBeats(state.timeSignature.beats - 1),
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${state.timeSignature.beats}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => controller.setBeats(state.timeSignature.beats + 1),
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: RytmaSpacing.lg),
              const Text('/', style: TextStyle(fontSize: 24)),
              const SizedBox(width: RytmaSpacing.lg),
              DropdownButton<int>(
                value: state.timeSignature.unit,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(kRadius),
                dropdownColor: RytmaColors.surface,
                items: [
                  for (final u in TimeSignature.units)
                    DropdownMenuItem(value: u, child: Text('$u')),
                ],
                onChanged: (u) => u != null ? controller.setUnit(u) : null,
              ),
            ],
          ),
          const SizedBox(height: RytmaSpacing.md),
          const BeatGrid(),
          const SizedBox(height: RytmaSpacing.sm),
          Center(
            child: Text(
              'Tap a beat to change its accent',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: RytmaSpacing.xl),
          const SectionLabel('Subdivision'),
          const SizedBox(height: RytmaSpacing.sm),
          const SubdivisionPicker(),
          const SizedBox(height: RytmaSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _savePresetDialog(context, controller),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save as preset'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePresetDialog(
    BuildContext context,
    MetronomeController controller,
  ) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save preset'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Preset name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) await controller.savePreset(name);
  }
}
