import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/audio_analyzer.dart';
import 'services/loop_recorder.dart';
import 'services/synth_audio.dart';
import 'state/app_settings.dart';
import 'state/metronome_controller.dart';
import 'state/sequencer_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MetronomeController();
  final looper = LoopRecorder();
  final analyzer = AudioAnalyzer();
  final settings = AppSettings()..load();
  final sequencer = SequencerController(audio: SynthAudio());

  // Drive the looper's bar-synced features from the metronome's transport.
  controller.bar.addListener(() => looper.handleBar(controller.currentBar));
  // The sequencer's tempo follows the metronome's BPM (unless overridden).
  controller.addListener(() => sequencer.setFollowedBpm(controller.state.bpm));

  runApp(RytmaApp(
    controller: controller,
    looper: looper,
    analyzer: analyzer,
    settings: settings,
    sequencer: sequencer,
  ));

  // Initialize audio sequentially so the shared SoLoud engine is set up once.
  await controller.init();
  await sequencer.init();
}

class RytmaApp extends StatelessWidget {
  const RytmaApp({
    super.key,
    required this.controller,
    required this.looper,
    required this.analyzer,
    required this.settings,
    required this.sequencer,
  });

  final MetronomeController controller;
  final LoopRecorder looper;
  final AudioAnalyzer analyzer;
  final AppSettings settings;
  final SequencerController sequencer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: looper),
        ChangeNotifierProvider.value(value: analyzer),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: sequencer),
      ],
      child: MaterialApp(
        title: 'Rytma',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
