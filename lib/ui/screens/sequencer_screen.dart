import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/synth.dart';
import '../../models/sequencer_pattern.dart';
import '../../state/sequencer_controller.dart';
import '../theme.dart';

/// Step sequencer for building looping backing tracks: drum rows plus pitched
/// bass and chord lanes, in a chosen key. Plays on its own transport; the tempo
/// follows the metronome unless overridden.
class SequencerScreen extends StatelessWidget {
  const SequencerScreen({super.key});

  // Layout metrics shared by the gutter and the scrolling cells.
  static const double cellW = 34;
  static const double laneH = 46;
  static const double rulerH = 24;
  static const double gutterW = 104;

  @override
  Widget build(BuildContext context) {
    final seq = context.watch<SequencerController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequencer'),
        actions: [
          IconButton(
            tooltip: 'Mixer',
            icon: const Icon(Icons.tune),
            onPressed: seq.isInitialized
                ? () => _showMixer(context, seq)
                : null,
          ),
          IconButton(
            tooltip: 'Clear pattern',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: seq.isInitialized ? seq.clear : null,
          ),
        ],
      ),
      body: !seq.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _Controls(seq: seq),
                const Divider(height: 1),
                Expanded(child: _Grid(seq: seq)),
              ],
            ),
    );
  }

  static Color _laneColor(_Lane lane) {
    switch (lane) {
      case _Lane.kick:
        return MetroColors.strong;
      case _Lane.snare:
        return MetroColors.poly;
      case _Lane.hat:
        return MetroColors.sub;
      case _Lane.clap:
        return MetroColors.weak;
      case _Lane.bass:
        return MetroColors.normal;
      case _Lane.chord:
        return MetroColors.playing;
      case _Lane.lead:
        return MetroColors.lead;
    }
  }

  static Future<void> _showMixer(
      BuildContext context, SequencerController seq) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<SequencerController>.value(
        value: seq,
        child: const _Mixer(),
      ),
    );
  }
}

enum _Lane { kick, snare, hat, clap, bass, chord, lead }

const _drumOf = {
  _Lane.kick: DrumKind.kick,
  _Lane.snare: DrumKind.snare,
  _Lane.hat: DrumKind.hat,
  _Lane.clap: DrumKind.clap,
};

const _laneLabels = {
  _Lane.kick: 'Kick',
  _Lane.snare: 'Snare',
  _Lane.hat: 'Hat',
  _Lane.clap: 'Clap',
  _Lane.bass: 'Bass',
  _Lane.chord: 'Chord',
  _Lane.lead: 'Lead',
};

/// Transport, tempo, length and key controls (the non-scrolling header).
class _Controls extends StatelessWidget {
  const _Controls({required this.seq});

  final SequencerController seq;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = seq.pattern;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: seq.toggle,
                icon: Icon(seq.isPlaying
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded),
                label: Text(seq.isPlaying ? 'Stop' : 'Play'),
                style: FilledButton.styleFrom(
                  backgroundColor: seq.isPlaying ? scheme.error : scheme.primary,
                  minimumSize: const Size(112, 44),
                ),
              ),
              const Spacer(),
              _Tempo(seq: seq),
            ],
          ),
          const SizedBox(height: MetroSpacing.sm),
          Row(
            children: [
              const Text('Steps'),
              const SizedBox(width: MetroSpacing.sm),
              DropdownButton<int>(
                value: p.steps,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(kRadius),
                dropdownColor: MetroColors.surface,
                items: [
                  for (final n in kSequencerLengths)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) => n != null ? seq.setSteps(n) : null,
              ),
              const Spacer(),
              const Text('Key'),
              const SizedBox(width: MetroSpacing.sm),
              DropdownButton<int>(
                value: p.root,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(kRadius),
                dropdownColor: MetroColors.surface,
                items: [
                  for (var r = 0; r < 12; r++)
                    DropdownMenuItem(value: r, child: Text(Music.rootName(r))),
                ],
                onChanged: (r) => r != null ? seq.setRoot(r) : null,
              ),
              const SizedBox(width: MetroSpacing.sm),
              SegmentedButton<SynthScale>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: SynthScale.major, label: Text('maj')),
                  ButtonSegment(value: SynthScale.minor, label: Text('min')),
                ],
                selected: {p.scale},
                onSelectionChanged: (s) => seq.setScale(s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tempo readout with a follow-metronome toggle and ± when overridden.
class _Tempo extends StatelessWidget {
  const _Tempo({required this.seq});

  final SequencerController seq;

  @override
  Widget build(BuildContext context) {
    final following = seq.followsMetronome;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!following) ...[
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: () => seq.setBpmOverride(seq.effectiveBpm - 1),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 2),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${seq.effectiveBpm.round()} BPM',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => seq.setBpmOverride(
                  following ? seq.effectiveBpm : null),
              child: Text(
                following ? 'follows metronome' : 'tap to follow',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (!following) ...[
          const SizedBox(width: 2),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: () => seq.setBpmOverride(seq.effectiveBpm + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ],
    );
  }
}

/// The scrollable step grid: a fixed label gutter plus a single horizontal
/// scroller holding the step ruler and every lane (so they scroll together).
class _Grid extends StatelessWidget {
  const _Grid({required this.seq});

  final SequencerController seq;

  @override
  Widget build(BuildContext context) {
    final p = seq.pattern;
    return ValueListenableBuilder<int>(
      valueListenable: seq.currentStep,
      builder: (context, playStep, _) {
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed gutter: labels + mute toggles.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                      height: SequencerScreen.rulerH,
                      width: SequencerScreen.gutterW),
                  for (final lane in _Lane.values)
                    _GutterHeader(seq: seq, lane: lane),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Ruler(steps: p.steps, playStep: playStep),
                      for (final lane in _Lane.values)
                        _LaneCells(seq: seq, lane: lane, playStep: playStep),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GutterHeader extends StatelessWidget {
  const _GutterHeader({required this.seq, required this.lane});

  final SequencerController seq;
  final _Lane lane;

  @override
  Widget build(BuildContext context) {
    final p = seq.pattern;
    final drum = _drumOf[lane];
    final muted = drum != null
        ? (p.drumMute[drum] ?? false)
        : switch (lane) {
            _Lane.bass => p.bassMute,
            _Lane.chord => p.chordMute,
            _ => p.leadMute,
          };
    final color = SequencerScreen._laneColor(lane);
    return SizedBox(
      height: SequencerScreen.laneH,
      width: SequencerScreen.gutterW,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: muted ? 'Unmute' : 'Mute',
            color: muted ? Theme.of(context).colorScheme.error : color,
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 18),
            onPressed: () {
              if (drum != null) {
                seq.toggleDrumMute(drum);
              } else if (lane == _Lane.bass) {
                seq.toggleBassMute();
              } else if (lane == _Lane.chord) {
                seq.toggleChordMute();
              } else {
                seq.toggleLeadMute();
              }
            },
          ),
          Text(_laneLabels[lane]!,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.steps, required this.playStep});

  final int steps;
  final int playStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SequencerScreen.rulerH,
      child: Row(
        children: [
          for (var s = 0; s < steps; s++)
            Container(
              width: SequencerScreen.cellW,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              child: Text(
                '${s + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: s == playStep
                      ? Colors.white
                      : (s % 4 == 0 ? Colors.white70 : Colors.white30),
                  fontWeight: s % 4 == 0 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LaneCells extends StatelessWidget {
  const _LaneCells(
      {required this.seq, required this.lane, required this.playStep});

  final SequencerController seq;
  final _Lane lane;
  final int playStep;

  @override
  Widget build(BuildContext context) {
    final p = seq.pattern;
    final color = SequencerScreen._laneColor(lane);
    final drum = _drumOf[lane];
    final list = drum == null ? _laneList(p) : null;

    return SizedBox(
      height: SequencerScreen.laneH,
      child: Row(
        children: [
          for (var s = 0; s < p.steps; s++)
            _Cell(
              color: color,
              playhead: s == playStep,
              beatGroup: s ~/ p.stepsPerBeat,
              active: drum != null ? p.drums[drum]![s] : list![s] != null,
              label: drum != null || list![s] == null
                  ? null
                  : _rowLabel(p, list[s]!),
              onTap: () => drum != null
                  ? seq.toggleDrum(drum, s)
                  : _pickPitch(context, s),
            ),
        ],
      ),
    );
  }

  List<int?> _laneList(SequencerPattern p) => switch (lane) {
        _Lane.bass => p.bass,
        _Lane.chord => p.chords,
        _ => p.lead,
      };

  int get _rowCount => switch (lane) {
        _Lane.bass => Music.bassRows,
        _Lane.chord => Music.chordRows,
        _ => Music.leadRows,
      };

  String _rowLabel(SequencerPattern p, int i) => switch (lane) {
        _Lane.bass => Music.bassLabel(p.root, p.scale, i),
        _Lane.chord => Music.chordLabel(p.root, p.scale, i),
        _ => Music.leadLabel(p.root, p.scale, i),
      };

  void _setRow(int step, int? value) => switch (lane) {
        _Lane.bass => seq.setBass(step, value),
        _Lane.chord => seq.setChord(step, value),
        _ => seq.setLead(step, value),
      };

  Future<void> _pickPitch(BuildContext context, int step) async {
    final p = seq.pattern;
    final current = _laneList(p)[step];
    final color = SequencerScreen._laneColor(lane);

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_laneLabels[lane]} · step ${step + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: MetroSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Rest'),
                  selected: current == null,
                  onSelected: (_) => Navigator.pop(ctx, -1),
                ),
                for (var i = 0; i < _rowCount; i++)
                  ChoiceChip(
                    label: Text(_rowLabel(p, i)),
                    selected: current == i,
                    selectedColor: color.withValues(alpha: 0.35),
                    onSelected: (_) => Navigator.pop(ctx, i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == null) return; // dismissed
    _setRow(step, result < 0 ? null : result);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.color,
    required this.active,
    required this.playhead,
    required this.beatGroup,
    required this.onTap,
    this.label,
  });

  final Color color;
  final bool active;
  final bool playhead;
  final int beatGroup;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SequencerScreen.cellW,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? color
              : color.withValues(alpha: beatGroup.isEven ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(7),
          border: playhead
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: label == null
            ? null
            : Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.black : Colors.white70,
                ),
              ),
      ),
    );
  }
}

/// Bottom-sheet mixer: per-track volume, plus a waveform selector for each of
/// the pitched (bass / chord / lead) synth voices.
class _Mixer extends StatelessWidget {
  const _Mixer();

  static const _waveLabel = {
    SynthWave.sine: 'sine',
    SynthWave.triangle: 'tri',
    SynthWave.saw: 'saw',
    SynthWave.square: 'square',
  };

  @override
  Widget build(BuildContext context) {
    final seq = context.watch<SequencerController>();
    final p = seq.pattern;

    Widget row(String name, double value, ValueChanged<double> onChanged,
        {Widget? trailing}) {
      return Row(
        children: [
          SizedBox(width: 56, child: Text(name)),
          Expanded(child: Slider(value: value, onChanged: onChanged)),
          ?trailing,
        ],
      );
    }

    Widget waveDropdown(SynthWave value, ValueChanged<SynthWave> onChanged) {
      return DropdownButton<SynthWave>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(kRadius),
        dropdownColor: MetroColors.surface,
        items: [
          for (final w in SynthWave.values)
            DropdownMenuItem(value: w, child: Text(_waveLabel[w]!)),
        ],
        onChanged: (w) => w != null ? onChanged(w) : null,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mixer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: MetroSpacing.sm),
          for (final k in DrumKind.values)
            row(_drumName(k), p.drumVol[k] ?? 0.9,
                (v) => seq.setDrumVolume(k, v)),
          row('Bass', p.bassVol, seq.setBassVolume,
              trailing: waveDropdown(p.bassWave, seq.setBassWave)),
          row('Chord', p.chordVol, seq.setChordVolume,
              trailing: waveDropdown(p.chordWave, seq.setChordWave)),
          row('Lead', p.leadVol, seq.setLeadVolume,
              trailing: waveDropdown(p.leadWave, seq.setLeadWave)),
        ],
      ),
    );
  }

  String _drumName(DrumKind k) => switch (k) {
        DrumKind.kick => 'Kick',
        DrumKind.snare => 'Snare',
        DrumKind.hat => 'Hat',
        DrumKind.clap => 'Clap',
      };
}
