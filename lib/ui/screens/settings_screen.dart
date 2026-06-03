import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_settings.dart';

/// App-wide preferences. Tuner reference pitch and spectrogram sensitivity live
/// on the Analyzer screen (where they're used); this hosts global options that
/// don't belong to any one feature.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.brightness_high_outlined),
              title: const Text('Keep screen awake'),
              subtitle: const Text(
                'Stop the display from dimming or locking while you practice.',
              ),
              value: settings.keepAwake,
              onChanged: settings.setKeepAwake,
            ),
          ),
        ],
      ),
    );
  }
}
