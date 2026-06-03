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

  // Looper channel transport states. `stopped` happens to match `poly` today,
  // but it is kept separate so tweaking one voice never silently recolors the
  // other.
  static const playing = Color(0xFF4CD964);
  static const stopped = Color(0xFFFFB300);

  // Surfaces (deep-dark, hand-picked to read as one continuous backdrop).
  static const background = Color(0xFF101014); // scaffold
  static const surface = Color(0xFF1B1B22); // cards, menus
  static const surfaceBar = Color(0xFF16161C); // transport + nav bars

  // Spectrogram heat ramp (intensity 0 → 1).
  static const heatFloor = Color(0xFF0B0B0F);
  static const heatLow = Color(0xFF1A1145);
  static const heatMid = Color(0xFFC2185B);
  static const heatHigh = Color(0xFFFFEB3B);
}

/// Shared spacing scale so gaps and padding stay on a consistent rhythm.
class MetroSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// The single standard corner radius used across cards, dialogs and tiles.
const double kRadius = 16;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MetroColors.seed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MetroColors.background,
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    cardTheme: CardThemeData(
      color: MetroColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    // Flat app bars that don't tint as content scrolls under them.
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    // Match the transport bar so the two stacked bottom bars read as one unit.
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: MetroColors.surfaceBar,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MetroColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
  );
}
