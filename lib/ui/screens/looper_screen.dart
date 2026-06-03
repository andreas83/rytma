import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../engine/tick_event.dart';
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
    final controller = context.watch<MetronomeController>();
    final state = controller.state;

    // Feed the metronome (master clock) to the looper: bar length for length
    // quantization and whether the transport is running for bar-synced starts.
    final beatMs = 60000.0 / state.bpm;
    final barSamples =
        (LoopRecorder.sampleRate * state.timeSignature.beats * beatMs / 1000)
            .round();
    recorder.setBarSamples(barSamples);
    recorder.setTransportRunning(controller.isPlaying);

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
          _BeatIndicator(controller: controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(
              children: [
                const Text('Fit to bars',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                SegmentedButton<LoopFit>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: LoopFit.off, label: Text('Off')),
                    ButtonSegment(value: LoopFit.crop, label: Text('Crop')),
                    ButtonSegment(value: LoopFit.warp, label: Text('Warp')),
                  ],
                  selected: {recorder.fit},
                  onSelectionChanged: (s) => recorder.setFit(s.first),
                ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.grid_on),
            title: const Text('Start loops on the bar'),
            subtitle: Text(
              controller.isPlaying
                  ? 'Record & playback snap to the bar · ${state.bpm.round()} BPM ${state.timeSignature}'
                  : 'Start the metronome to align loops to the grid',
            ),
            value: recorder.quantizeStart,
            onChanged: recorder.setQuantizeStart,
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
                _RecordButton(
                  recorder: recorder,
                  channel: channel,
                  fill: style.fill,
                  icon: style.icon,
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
      case ChannelState.armedRecord:
        return _PadStyle(
          fill: scheme.tertiary,
          dot: scheme.tertiary,
          icon: Icons.fiber_manual_record,
          label: 'Armed — records next bar',
        );
      case ChannelState.recording:
        return _PadStyle(
          fill: scheme.error,
          dot: scheme.error,
          icon: Icons.stop_rounded,
          label: 'Recording… tap to loop',
        );
      case ChannelState.armedStop:
        return _PadStyle(
          fill: scheme.error,
          dot: scheme.tertiary,
          icon: Icons.stop_rounded,
          label: 'Armed — loops next bar',
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

/// A row of dots that lights up the current metronome beat, so the looper shows
/// where you are in the bar without watching the Metronome tab. Driven by the
/// controller's [MetronomeController.pulse] so it repaints in isolation.
class _BeatIndicator extends StatelessWidget {
  const _BeatIndicator({required this.controller});

  final MetronomeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final beats = controller.state.timeSignature.beats;
    return SizedBox(
      height: 28,
      child: ValueListenableBuilder<TickEvent?>(
        valueListenable: controller.pulse,
        builder: (context, tick, _) {
          final active = (tick != null && tick.voice == 0) ? tick.beat : -1;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(beats, (i) {
              final on = i == active;
              final color = on
                  ? (i == 0 ? scheme.tertiary : scheme.primary)
                  : scheme.onSurface.withValues(alpha: 0.18);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 70),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 14 : 9,
                height: on ? 14 : 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// The circular record/transport pad with a live progress ring. While the
/// channel records, the ring sweeps once per bar (tracking the captured audio
/// length); while armed, it pulses to signal it fires on the next bar.
class _RecordButton extends StatefulWidget {
  const _RecordButton({
    required this.recorder,
    required this.channel,
    required this.fill,
    required this.icon,
  });

  final LoopRecorder recorder;
  final LoopChannel channel;
  final Color fill;
  final IconData icon;

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  bool get _animating =>
      widget.channel.state == ChannelState.recording || widget.channel.isArmed;

  void _syncTicker() {
    if (_animating && !_ticker.isActive) {
      _ticker.start();
    } else if (!_animating && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTicker();

    final recording = widget.channel.state == ChannelState.recording;
    final armed = widget.channel.isArmed;
    final bar = widget.recorder.barSamples;
    final progress = recording && bar > 0
        ? (widget.recorder.recordedSamples % bar) / bar
        : 0.0;
    // Armed pads breathe; the value cycles 0→1→0 a bit faster than once a second.
    final pulse = armed
        ? (0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 180))
        : 0.0;

    return GestureDetector(
      onTap: () => widget.recorder.tapChannel(widget.channel.index),
      child: SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _RingPainter(
            color: widget.fill,
            progress: progress,
            recording: recording,
            pulse: pulse,
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.fill,
                boxShadow: [
                  BoxShadow(
                    color: widget.fill.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the progress ring around a [_RecordButton]: a faint track plus a
/// bright arc that sweeps with the recording position (or a pulsing full ring
/// while armed).
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.color,
    required this.progress,
    required this.recording,
    required this.pulse,
  });

  final Color color;
  final double progress;
  final bool recording;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (!recording && pulse == 0.0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: recording ? 0.95 : 0.4 + 0.5 * pulse);

    if (recording) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
    } else {
      // Armed: a breathing full ring.
      canvas.drawCircle(center, radius, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.recording != recording ||
      old.pulse != pulse ||
      old.color != color;
}
