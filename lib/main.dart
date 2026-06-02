import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/audio_analyzer.dart';
import 'services/loop_recorder.dart';
import 'state/metronome_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetroPowerApp());
}

class MetroPowerApp extends StatelessWidget {
  const MetroPowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MetronomeController()..init()),
        ChangeNotifierProvider(create: (_) => LoopRecorder()),
        ChangeNotifierProvider(create: (_) => AudioAnalyzer()),
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
