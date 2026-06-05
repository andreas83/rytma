import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_analyzer.dart';
import '../../state/app_settings.dart';
import '../../state/metronome_controller.dart';
import '../theme.dart';
import '../widgets/spectrogram_view.dart';
import '../widgets/tuner_gauge.dart';
import '../widgets/tuner_history_chart.dart';

enum _Mode { tuner, spectrogram }

/// Microphone-analysis screen with two modes that share one audio stream:
/// a chromatic tuner (Stimmgerät) and a live spectrogram that can overlay the
/// metronome's bar downbeats.
class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  _Mode _mode = _Mode.tuner;
  bool _showBars = true;
  MetronomeController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<MetronomeController>();
    if (controller != _controller) {
      _controller?.pulse.removeListener(_onPulse);
      _controller = controller;
      _controller!.pulse.addListener(_onPulse);
    }
  }

  void _onPulse() {
    if (!mounted) return;
    final tick = _controller?.pulse.value;
    if (tick != null && tick.voice == 0 && tick.beat == 0 && tick.sub == 0) {
      context.read<AudioAnalyzer>().markBar();
    }
  }

  @override
  void dispose() {
    _controller?.pulse.removeListener(_onPulse);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyzer = context.watch<AudioAnalyzer>();
    final settings = context.watch<AppSettings>();
    // Feed the analyzer the current preferences (cheap, idempotent setters).
    analyzer.setReferenceA4(settings.referenceA4);
    analyzer.setSensitivity(settings.spectrogramSensitivity);

    return Scaffold(
      appBar: AppBar(title: const Text('Analyzer')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                  value: _Mode.tuner,
                  icon: Icon(Icons.music_note),
                  label: Text('Tuner'),
                ),
                ButtonSegment(
                  value: _Mode.spectrogram,
                  icon: Icon(Icons.graphic_eq),
                  label: Text('Spectrogram'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: MetroSpacing.md),
            _ListeningBar(analyzer: analyzer),
            if (analyzer.error != null)
              Padding(
                padding: const EdgeInsets.only(top: MetroSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MetroSpacing.md, vertical: MetroSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: MetroSpacing.sm),
                      Expanded(
                        child: Text(
                          analyzer.error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: MetroSpacing.lg),
            Expanded(
              child: _mode == _Mode.tuner
                  ? _TunerBody(analyzer: analyzer, settings: settings)
                  : _SpectrogramBody(
                      analyzer: analyzer,
                      settings: settings,
                      showBars: _showBars,
                      onShowBars: (v) => setState(() => _showBars = v),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Passive listening indicator with an input-level meter. The mic starts and
/// stops automatically with the Analyzer tab, so there is no manual button.
class _ListeningBar extends StatelessWidget {
  const _ListeningBar({required this.analyzer});

  final AudioAnalyzer analyzer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = analyzer.isRunning;
    // Map RMS (~0..0.3) to a 0..1 bar.
    final level = (analyzer.level * 3.2).clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(running ? Icons.mic : Icons.mic_off,
            color: running ? scheme.primary : Colors.white38, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: running ? level : 0,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(running ? 'Listening' : 'Idle',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TunerBody extends StatelessWidget {
  const _TunerBody({required this.analyzer, required this.settings});

  final AudioAnalyzer analyzer;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            TunerGauge(reading: analyzer.reading),
            const SizedBox(height: MetroSpacing.md),
            TunerHistoryChart(history: analyzer.centsHistory),
            const SizedBox(height: MetroSpacing.lg),
            _ReferencePitch(settings: settings),
            const SizedBox(height: MetroSpacing.md),
            Text(
              'Play a single note to tune. Green band = in tune.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact stepper for the concert-pitch reference (A4), e.g. 432 / 440 / 442.
class _ReferencePitch extends StatelessWidget {
  const _ReferencePitch({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a4 = settings.referenceA4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Reference', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(width: MetroSpacing.md),
        IconButton.filledTonal(
          tooltip: '−1 Hz',
          visualDensity: VisualDensity.compact,
          onPressed:
              a4 > AppSettings.minA4 ? () => settings.nudgeReferenceA4(-1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 116,
          child: Text(
            'A4 = ${a4.round()} Hz',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: '+1 Hz',
          visualDensity: VisualDensity.compact,
          onPressed:
              a4 < AppSettings.maxA4 ? () => settings.nudgeReferenceA4(1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _SpectrogramBody extends StatelessWidget {
  const _SpectrogramBody({
    required this.analyzer,
    required this.settings,
    required this.showBars,
    required this.onShowBars,
  });

  final AudioAnalyzer analyzer;
  final AppSettings settings;
  final bool showBars;
  final ValueChanged<bool> onShowBars;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SpectrogramView(
            columns: analyzer.spectrogram,
            markers: analyzer.markers,
            showBars: showBars,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: MetroSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: MetroSpacing.sm),
              const Text('Sensitivity'),
              Expanded(
                child: Slider(
                  value: settings.spectrogramSensitivity,
                  label: '${(settings.spectrogramSensitivity * 100).round()}%',
                  divisions: 20,
                  onChanged: settings.setSpectrogramSensitivity,
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show metronome bar lines'),
          subtitle: const Text('Marks each downbeat while the metronome runs'),
          value: showBars,
          onChanged: onShowBars,
        ),
      ],
    );
  }
}
