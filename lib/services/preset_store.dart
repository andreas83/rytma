import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/metronome_state.dart';
import '../models/preset.dart';

/// Persists saved [Preset]s and the most recent [MetronomeState] using
/// [shared_preferences]. State is stored as JSON strings.
class PresetStore {
  static const _presetsKey = 'rytma.presets';
  static const _lastKey = 'rytma.last_state';

  Future<List<Preset>> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_presetsKey) ?? const [];
    final result = <Preset>[];
    for (final entry in raw) {
      try {
        result.add(Preset.fromJson(jsonDecode(entry) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt entries rather than failing the whole load.
      }
    }
    return result;
  }

  Future<void> savePresets(List<Preset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = presets.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_presetsKey, raw);
  }

  Future<void> saveLast(MetronomeState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, jsonEncode(state.toJson()));
  }

  Future<MetronomeState?> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastKey);
    if (raw == null) return null;
    try {
      return MetronomeState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
