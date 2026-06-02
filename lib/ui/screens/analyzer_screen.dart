import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_analyzer.dart';
import '../../state/metronome_controller.dart';
import '../widgets/spectrogram_view.dart';
import '../widgets/tuner_gauge.dart';

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
            const SizedBox(height: 12),
            _MicButton(analyzer: analyzer),
            if (analyzer.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  analyzer.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _mode == _Mode.tuner
                  ? _TunerBody(analyzer: analyzer)
                  : _SpectrogramBody(
                      analyzer: analyzer,
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

class _MicButton extends StatelessWidget {
  const _MicButton({required this.analyzer});

  final AudioAnalyzer analyzer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: () => analyzer.isRunning ? analyzer.stop() : analyzer.start(),
      icon: Icon(analyzer.isRunning ? Icons.stop : Icons.mic),
      label: Text(analyzer.isRunning ? 'Stop listening' : 'Start listening'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: analyzer.isRunning ? scheme.error : scheme.primary,
      ),
    );
  }
}

class _TunerBody extends StatelessWidget {
  const _TunerBody({required this.analyzer});

  final AudioAnalyzer analyzer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            TunerGauge(reading: analyzer.reading),
            const SizedBox(height: 16),
            Text(
              analyzer.isRunning
                  ? 'Play a single note to tune (A4 = 440 Hz).'
                  : 'Tap “Start listening” and play a note.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrogramBody extends StatelessWidget {
  const _SpectrogramBody({
    required this.analyzer,
    required this.showBars,
    required this.onShowBars,
  });

  final AudioAnalyzer analyzer;
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
