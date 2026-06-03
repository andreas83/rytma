import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/loop_recorder.dart';
import '../../state/metronome_controller.dart';

/// Looper screen — a multi-channel loop station. Each channel records into an
/// in-memory loop that plays through the shared audio engine, so several
/// channels sound at once. Per channel: play/stop, volume, mute, one-shot, trim
/// and clear; loops can be length-synced to the metronome (the master clock).
class LooperScreen extends StatelessWidget {
  const LooperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<LoopRecorder>();
    final state = context.watch<MetronomeController>().state;

    // Feed the metronome's bar length (master clock) to the looper for
    // length quantization.
    final beatMs = 60000.0 / state.bpm;
    final barSamples =
        (LoopRecorder.sampleRate * state.timeSignature.beats * beatMs / 1000)
            .round();
    recorder.setBarSamples(barSamples);

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
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.straighten),
            title: const Text('Sync length to metronome'),
            subtitle: Text(
              'Quantize loops to whole bars · ${state.bpm.round()} BPM '
              '${state.timeSignature}',
            ),
            value: recorder.syncEnabled,
            onChanged: recorder.setSync,
          ),
          if (recorder.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                recorder.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: LoopRecorder.channelCount,
              itemBuilder: (context, i) =>
                  _ChannelCard(recorder: recorder, channel: recorder.channels[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.recorder, required this.channel});

  final LoopRecorder recorder;
  final LoopChannel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _padStyle(channel.state, scheme);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => recorder.tapChannel(channel.index),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.fill,
                      boxShadow: [
                        BoxShadow(
                          color: style.fill.withValues(alpha: 0.4),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(style.icon, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Channel ${channel.index + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(style.label,
                          style: TextStyle(color: style.dot, fontSize: 12)),
                    ],
                  ),
                ),
                if (channel.hasLoop)
                  IconButton(
                    tooltip: channel.oneShot ? 'One-shot' : 'Looping',
                    isSelected: channel.oneShot,
                    icon: Icon(channel.oneShot ? Icons.looks_one : Icons.repeat),
                    onPressed: () =>
                        recorder.setOneShot(channel.index, !channel.oneShot),
                  ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: channel.state == ChannelState.empty
                      ? null
                      : () => recorder.clearChannel(channel.index),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Mute',
                  isSelected: channel.muted,
                  color: channel.muted ? scheme.error : null,
                  icon: Icon(
                      channel.muted ? Icons.volume_off : Icons.volume_up,
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
              ],
            ),
            if (channel.hasLoop)
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 4),
                    child: Icon(Icons.content_cut, size: 18),
                  ),
                  Expanded(
                    child: RangeSlider(
                      values: RangeValues(channel.trimStart, channel.trimEnd),
                      labels: RangeLabels(
                        '${(channel.trimStart * 100).round()}%',
                        '${(channel.trimEnd * 100).round()}%',
                      ),
                      onChanged: (v) =>
                          recorder.setTrim(channel.index, v.start, v.end),
                      onChangeEnd: (_) => recorder.applyTrim(channel.index),
                    ),
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
          label: 'Recording… tap to loop',
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
