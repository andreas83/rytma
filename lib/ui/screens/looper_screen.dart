import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/loop_recorder.dart';

/// Looper screen: record microphone takes that loop continuously and stack as
/// layers over the metronome, with per-layer volume / mute / solo plus undo,
/// stop-all and clear.
class LooperScreen extends StatelessWidget {
  const LooperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<LoopRecorder>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Looper'),
        actions: [
          IconButton(
            tooltip: 'Undo last loop',
            icon: const Icon(Icons.undo),
            onPressed: recorder.isEmpty ? null : recorder.undoLast,
          ),
          IconButton(
            tooltip: recorder.isPlaying ? 'Stop all' : 'Play all',
            icon: Icon(recorder.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: recorder.isEmpty ? null : recorder.togglePlayAll,
          ),
          IconButton(
            tooltip: 'Clear all loops',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: recorder.isEmpty ? null : recorder.clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
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
          const Divider(height: 28),
          Expanded(
            child: recorder.isEmpty
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
                    itemBuilder: (context, i) => _LayerCard(
                      recorder: recorder,
                      index: i,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  const _LayerCard({required this.recorder, required this.index});

  final LoopRecorder recorder;
  final int index;

  @override
  Widget build(BuildContext context) {
    final layer = recorder.layers[index];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text('Loop ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Mute',
                  isSelected: layer.muted,
                  icon: Icon(layer.muted ? Icons.volume_off : Icons.volume_up),
                  color: layer.muted ? scheme.error : null,
                  onPressed: () => recorder.toggleMute(layer.id),
                ),
                IconButton(
                  tooltip: 'Solo',
                  icon: const Text('S', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => recorder.toggleSolo(layer.id),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => recorder.removeLayer(layer.id),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.graphic_eq, size: 18),
                Expanded(
                  child: Slider(
                    value: layer.volume,
                    onChanged: (v) => recorder.setVolume(layer.id, v),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${(layer.volume * 100).round()}%',
                      textAlign: TextAlign.end),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
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
        width: 116,
        height: 116,
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
          size: 54,
          color: Colors.white,
        ),
      ),
    );
  }
}
