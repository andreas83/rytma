import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/loop_recorder.dart';

/// Looper screen — a multi-channel loop station. Each channel is a pad you can
/// record into; all recorded channels loop together over the metronome, with
/// per-channel volume / mute / play-stop and global play-all / clear.
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
            tooltip: recorder.anyPlaying ? 'Stop all' : 'Play all',
            icon: Icon(recorder.anyPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: recorder.isEmpty ? null : recorder.togglePlayAll,
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: recorder.isEmpty ? null : recorder.clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              recorder.isRecording
                  ? 'Recording channel ${recorder.recordingIndex! + 1}… tap it again to loop.'
                  : 'Tap a channel to record; tap again to loop it. '
                      'Channels play together.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (recorder.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                recorder.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 232,
              ),
              itemCount: LoopRecorder.channelCount,
              itemBuilder: (context, i) =>
                  _ChannelPad(recorder: recorder, channel: recorder.channels[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPad extends StatelessWidget {
  const _ChannelPad({required this.recorder, required this.channel});

  final LoopRecorder recorder;
  final LoopChannel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _padStyle(channel.state, scheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text('Channel ${channel.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: style.dot),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => recorder.tapChannel(channel.index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.fill,
                      boxShadow: [
                        BoxShadow(
                          color: style.fill.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(style.icon, size: 38, color: Colors.white),
                  ),
                ),
              ),
            ),
            Text(style.label, style: TextStyle(color: style.dot, fontSize: 12)),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Mute',
                  isSelected: channel.muted,
                  color: channel.muted ? scheme.error : null,
                  icon: Icon(channel.muted ? Icons.volume_off : Icons.volume_up,
                      size: 20),
                  onPressed: channel.hasLoop
                      ? () => recorder.toggleMute(channel.index)
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: channel.volume,
                    onChanged: channel.hasLoop
                        ? (v) => recorder.setVolume(channel.index, v)
                        : null,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: channel.state == ChannelState.empty
                      ? null
                      : () => recorder.clearChannel(channel.index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _PadStyle _padStyle(ChannelState state, ColorScheme scheme) {
    switch (state) {
      case ChannelState.empty:
        return _PadStyle(
          fill: scheme.primary,
          dot: Colors.white38,
          icon: Icons.fiber_manual_record,
          label: 'Empty — tap to record',
        );
      case ChannelState.recording:
        return _PadStyle(
          fill: scheme.error,
          dot: scheme.error,
          icon: Icons.stop_rounded,
          label: 'Recording…',
        );
      case ChannelState.playing:
        return const _PadStyle(
          fill: Color(0xFF4CD964),
          dot: Color(0xFF4CD964),
          icon: Icons.pause,
          label: 'Playing',
        );
      case ChannelState.stopped:
        return const _PadStyle(
          fill: Color(0xFFFFB300),
          dot: Color(0xFFFFB300),
          icon: Icons.play_arrow,
          label: 'Stopped',
        );
    }
  }
}

class _PadStyle {
  const _PadStyle({
    required this.fill,
    required this.dot,
    required this.icon,
    required this.label,
  });

  final Color fill;
  final Color dot;
  final IconData icon;
  final String label;
}
