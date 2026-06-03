import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/audio_analyzer.dart';
import 'services/loop_recorder.dart';
import 'state/app_settings.dart';
import 'state/metronome_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MetronomeController()..init();
  final looper = LoopRecorder();
  final analyzer = AudioAnalyzer();
  final settings = AppSettings()..load();

  // Drive the looper's bar-synced features from the metronome's transport.
  controller.bar.addListener(() => looper.handleBar(controller.currentBar));

  runApp(MetroPowerApp(
    controller: controller,
    looper: looper,
    analyzer: analyzer,
    settings: settings,
  ));
}

class MetroPowerApp extends StatelessWidget {
  const MetroPowerApp({
    super.key,
    required this.controller,
    required this.looper,
    required this.analyzer,
    required this.settings,
  });

  final MetronomeController controller;
  final LoopRecorder looper;
  final AudioAnalyzer analyzer;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: looper),
        ChangeNotifierProvider.value(value: analyzer),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: MaterialApp(
        title: 'Metro Power',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
