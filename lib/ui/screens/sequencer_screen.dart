import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/synth.dart';
import '../../engine/track_export.dart';
import '../../models/sequencer_pattern.dart';
import '../../services/track_export_delivery.dart';
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
            tooltip: 'FX rack',
            icon: const Icon(Icons.graphic_eq),
            onPressed: seq.isInitialized ? () => _showFx(context, seq) : null,
          ),
          IconButton(
            tooltip: 'Mixer',
            icon: const Icon(Icons.tune),
            onPressed: seq.isInitialized
                ? () => _showMixer(context, seq)
                : null,
          ),
          IconButton(
            tooltip: 'Export WAV',
            icon: const Icon(Icons.ios_share),
            onPressed: seq.isInitialized ? () => _exportWav(context, seq) : null,
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
                _SongBar(seq: seq),
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

  static Future<void> _showFx(BuildContext context, SequencerController seq) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<SequencerController>.value(
        value: seq,
        child: const _FxRack(),
      ),
    );
  }

  static Future<void> _exportWav(
      BuildContext context, SequencerController seq) async {
    final loops = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export WAV'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('Bounce the pattern (dry — no FX) to a WAV file.',
                style: TextStyle(fontSize: 13)),
          ),
          for (final n in [1, 2, 4, 8])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text('$n loop${n == 1 ? '' : 's'}'),
            ),
        ],
      ),
    );
    if (loops == null || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes =
          renderPattern(seq.pattern, bpm: seq.effectiveBpm, loops: loops);
      await deliverWav(bytes, 'metro-power.wav');
      navigator.pop(); // close spinner
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
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

String _patternLetter(int i) => String.fromCharCode(65 + i);

/// Pattern bank (A–H) + a Song toggle and arrangement strip.
class _SongBar extends StatelessWidget {
  const _SongBar({required this.seq});

  final SequencerController seq;

  @override
  Widget build(BuildContext context) {
    final canAdd = seq.patternCount < 8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < seq.patternCount; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(_patternLetter(i)),
                            visualDensity: VisualDensity.compact,
                            selected: i == seq.editIndex,
                            onSelected: (_) => seq.selectPattern(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add pattern',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 20),
                onPressed: canAdd ? seq.addPattern : null,
              ),
              IconButton(
                tooltip: 'Duplicate pattern',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                onPressed: canAdd ? seq.duplicatePattern : null,
              ),
              IconButton(
                tooltip: 'Delete pattern',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: seq.patternCount > 1
                    ? () => seq.deletePattern(seq.editIndex)
                    : null,
              ),
              const SizedBox(width: 4),
              FilterChip(
                label: const Text('Song'),
                visualDensity: VisualDensity.compact,
                selected: seq.songMode,
                onSelected: seq.setSongMode,
              ),
            ],
          ),
          if (seq.songMode)
            Row(
              children: [
                const Text('Arr', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < seq.arrangement.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              label: Text(
                                  '${_patternLetter(seq.arrangement[i].patternIndex)}×${seq.arrangement[i].repeats}'),
                              visualDensity: VisualDensity.compact,
                              selected: i == seq.playingArrangement,
                              // Tap bumps the repeat count (wraps 1→8→1).
                              onPressed: () => seq.setArrangementRepeats(
                                  i, seq.arrangement[i].repeats % 8 + 1),
                              onDeleted: seq.arrangement.length > 1
                                  ? () => seq.removeArrangementStep(i)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add current pattern to song',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.playlist_add, size: 20),
                  onPressed: () => seq.addArrangementStep(seq.editIndex),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

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
              velocity: _velAt(p, drum, s),
              prob: _probAt(p, drum, s),
              active: drum != null ? p.drums[drum]![s] : list![s] != null,
              label: drum != null || list![s] == null
                  ? null
                  : _rowLabel(p, list[s]!),
              onTap: () => drum != null
                  ? seq.toggleDrum(drum, s)
                  : _pickPitch(context, s),
              onLongPress: () => _editDynamics(context, s),
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

  StepVelocity _velAt(SequencerPattern p, DrumKind? drum, int s) =>
      drum != null
          ? p.drumVelocity[drum]![s]
          : switch (lane) {
              _Lane.bass => p.bassVelocity[s],
              _Lane.chord => p.chordVelocity[s],
              _ => p.leadVelocity[s],
            };

  double _probAt(SequencerPattern p, DrumKind? drum, int s) => drum != null
      ? p.drumProb[drum]![s]
      : switch (lane) {
          _Lane.bass => p.bassProb[s],
          _Lane.chord => p.chordProb[s],
          _ => p.leadProb[s],
        };

  Future<void> _editDynamics(BuildContext context, int step) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<SequencerController>.value(
        value: seq,
        child: _DynamicsSheet(lane: lane, drum: _drumOf[lane], step: step),
      ),
    );
  }

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
    required this.velocity,
    required this.prob,
    required this.onTap,
    required this.onLongPress,
    this.label,
  });

  final Color color;
  final bool active;
  final bool playhead;
  final int beatGroup;
  final StepVelocity velocity;
  final double prob;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? label;

  Color get _fill {
    if (!active) {
      return color.withValues(alpha: beatGroup.isEven ? 0.14 : 0.07);
    }
    return switch (velocity) {
      StepVelocity.ghost => color.withValues(alpha: 0.5),
      StepVelocity.normal => color,
      StepVelocity.accent =>
        Color.alphaBlend(Colors.white.withValues(alpha: 0.32), color),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: SequencerScreen.cellW,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(7),
          border: playhead
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (label != null)
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.black : Colors.white70,
                ),
              ),
            // A small dot marks a step that only triggers some of the time.
            if (active && prob < 1.0)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet editor for a single cell's dynamics: velocity + probability.
class _DynamicsSheet extends StatelessWidget {
  const _DynamicsSheet(
      {required this.lane, required this.drum, required this.step});

  final _Lane lane;
  final DrumKind? drum;
  final int step;

  @override
  Widget build(BuildContext context) {
    final seq = context.watch<SequencerController>();
    final p = seq.pattern;
    final velocity = drum != null
        ? p.drumVelocity[drum]![step]
        : switch (lane) {
            _Lane.bass => p.bassVelocity[step],
            _Lane.chord => p.chordVelocity[step],
            _ => p.leadVelocity[step],
          };
    final prob = drum != null
        ? p.drumProb[drum]![step]
        : switch (lane) {
            _Lane.bass => p.bassProb[step],
            _Lane.chord => p.chordProb[step],
            _ => p.leadProb[step],
          };

    void setVelocity(StepVelocity v) {
      if (drum != null) {
        seq.setDrumVelocity(drum!, step, v);
      } else {
        switch (lane) {
          case _Lane.bass:
            seq.setBassVelocity(step, v);
          case _Lane.chord:
            seq.setChordVelocity(step, v);
          default:
            seq.setLeadVelocity(step, v);
        }
      }
    }

    void setProb(double value) {
      if (drum != null) {
        seq.setDrumProbability(drum!, step, value);
      } else {
        switch (lane) {
          case _Lane.bass:
            seq.setBassProbability(step, value);
          case _Lane.chord:
            seq.setChordProbability(step, value);
          default:
            seq.setLeadProbability(step, value);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_laneLabels[lane]} · step ${step + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: MetroSpacing.md),
          const Text('Velocity'),
          const SizedBox(height: MetroSpacing.xs),
          SegmentedButton<StepVelocity>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: StepVelocity.ghost, label: Text('Ghost')),
              ButtonSegment(value: StepVelocity.normal, label: Text('Normal')),
              ButtonSegment(value: StepVelocity.accent, label: Text('Accent')),
            ],
            selected: {velocity},
            onSelectionChanged: (s) => setVelocity(s.first),
          ),
          const SizedBox(height: MetroSpacing.md),
          Row(
            children: [
              const Text('Chance'),
              Expanded(
                child: Slider(
                  value: prob,
                  divisions: 20,
                  label: '${(prob * 100).round()}%',
                  onChanged: setProb,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(prob * 100).round()}%',
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        ],
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
          Row(
            children: [
              const SizedBox(width: 56, child: Text('Swing')),
              Expanded(
                child: Slider(
                  value: p.swing,
                  max: 0.5,
                  divisions: 10,
                  label: '${(p.swing * 200).round()}%',
                  onChanged: seq.setSwing,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${(p.swing * 200).round()}%',
                    textAlign: TextAlign.end),
              ),
            ],
          ),
          const Divider(),
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

/// Bottom-sheet FX rack: real-time effects applied to the sequencer's synth
/// bus (reverb / delay / resonant low-pass filter / glue compressor).
class _FxRack extends StatelessWidget {
  const _FxRack();

  @override
  Widget build(BuildContext context) {
    final seq = context.watch<SequencerController>();
    final fx = seq.fx;

    Widget knob(String name, double value, ValueChanged<double> onChanged) =>
        Row(
          children: [
            SizedBox(width: 84, child: Text(name)),
            Expanded(child: Slider(value: value, onChanged: onChanged)),
          ],
        );

    Widget section(String title, bool on, VoidCallback onToggle,
            List<Widget> body) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              value: on,
              onChanged: (_) => onToggle(),
            ),
            if (on) ...body,
            const Divider(),
          ],
        );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FX rack',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Text('Effects on the sequencer voices only.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: MetroSpacing.sm),
          section('Reverb', fx.reverbOn, seq.toggleReverb, [
            knob('Mix', fx.reverbWet, seq.setReverbWet),
            knob('Room', fx.reverbRoom, seq.setReverbRoom),
          ]),
          section('Delay', fx.echoOn, seq.toggleEcho, [
            knob('Mix', fx.echoWet, seq.setEchoWet),
            knob('Time', fx.echoDelay, seq.setEchoDelay),
            knob('Feedback', fx.echoDecay, seq.setEchoDecay),
          ]),
          section('Low-pass filter', fx.lpfOn, seq.toggleLpf, [
            knob('Cutoff', fx.lpfCutoff, seq.setLpfCutoff),
            knob('Resonance', fx.lpfResonance, seq.setLpfResonance),
          ]),
          section('Compressor', fx.compOn, seq.toggleComp, const []),
        ],
      ),
    );
  }
}
