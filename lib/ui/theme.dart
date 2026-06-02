import 'package:flutter/material.dart';

/// Central color palette for click types and accents, plus the app theme.
class MetroColors {
  static const seed = Color(0xFF7C4DFF);
  static const strong = Color(0xFFFF5252);
  static const normal = Color(0xFF7C4DFF);
  static const weak = Color(0xFF40C4FF);
  static const mute = Color(0xFF455A64);
  static const sub = Color(0xFF80CBC4);
  static const poly = Color(0xFFFFB300);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MetroColors.seed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF101014),
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1B1B22),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
