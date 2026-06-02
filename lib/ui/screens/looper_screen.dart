import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/loop_recorder.dart';

/// Looper screen: record microphone takes that loop continuously and stack as
/// layers over the metronome.
class LooperScreen extends StatelessWidget {
  const LooperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<LoopRecorder>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Looper'),
        actions: [
          if (recorder.layers.isNotEmpty)
            IconButton(
              tooltip: 'Clear all loops',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: recorder.clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          _RecordButton(recorder: recorder),
          const SizedBox(height: 8),
          Text(
            recorder.isRecording ? 'Recording…' : 'Tap to record a loop',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (recorder.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                recorder.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(height: 32),
          Expanded(
            child: recorder.layers.isEmpty
                ? Center(
                    child: Text(
                      'No loops yet.\nRecord over the running metronome to build layers.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: recorder.layers.length,
                    itemBuilder: (context, i) {
                      final layer = recorder.layers[i];
                      return Card(
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(layer.playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill),
                            onPressed: () => recorder.toggleLayer(layer.id),
                          ),
                          title: Text('Loop ${i + 1}'),
                          subtitle: Text(layer.playing ? 'Playing' : 'Paused'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => recorder.removeLayer(layer.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recorder});

  final LoopRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: recorder.toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recorder.isRecording ? scheme.error : scheme.primary,
          boxShadow: [
            BoxShadow(
              color: (recorder.isRecording ? scheme.error : scheme.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          recorder.isRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }
}
