import 'package:flutter/material.dart';

import 'screens/analyzer_screen.dart';
import 'screens/looper_screen.dart';
import 'screens/metronome_screen.dart';
import 'screens/polyrhythm_screen.dart';
import 'screens/training_screen.dart';
import 'widgets/transport_bar.dart';

/// Root scaffold: an [IndexedStack] of the four feature screens, a persistent
/// [TransportBar], and a [NavigationBar] for switching between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    MetronomeScreen(),
    PolyrhythmScreen(),
    TrainingScreen(),
    LooperScreen(),
    AnalyzerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TransportBar(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.av_timer_outlined),
                selectedIcon: Icon(Icons.av_timer),
                label: 'Metronome',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_goldenratio_outlined),
                selectedIcon: Icon(Icons.grid_goldenratio),
                label: 'Polyrhythm',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Training',
              ),
              NavigationDestination(
                icon: Icon(Icons.loop_outlined),
                selectedIcon: Icon(Icons.loop),
                label: 'Looper',
              ),
              NavigationDestination(
                icon: Icon(Icons.graphic_eq_outlined),
                selectedIcon: Icon(Icons.graphic_eq),
                label: 'Analyzer',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
