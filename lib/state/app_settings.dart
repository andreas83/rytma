import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// App-wide preferences that live outside a metronome [MetronomeState]:
/// the tuner's reference pitch, the spectrogram's display sensitivity, and
/// whether to keep the screen awake. Persisted directly via
/// [shared_preferences] and exposed as a [ChangeNotifier] provider.
class AppSettings extends ChangeNotifier {
  static const _kRefA4 = 'rytma.reference_a4';
  static const _kSensitivity = 'rytma.spectrogram_sensitivity';
  static const _kKeepAwake = 'rytma.keep_awake';

  /// Reasonable bounds for the concert-pitch reference (Baroque 415 → high 466).
  static const double minA4 = 415;
  static const double maxA4 = 466;

  double _referenceA4 = 440;
  double _spectrogramSensitivity = 0.5; // 0..1, 0.5 == neutral / current look
  bool _keepAwake = false;

  double get referenceA4 => _referenceA4;
  double get spectrogramSensitivity => _spectrogramSensitivity;
  bool get keepAwake => _keepAwake;

  /// Load persisted settings and apply side effects (wakelock).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _referenceA4 = (prefs.getDouble(_kRefA4) ?? 440).clamp(minA4, maxA4);
    _spectrogramSensitivity =
        (prefs.getDouble(_kSensitivity) ?? 0.5).clamp(0.0, 1.0);
    _keepAwake = prefs.getBool(_kKeepAwake) ?? false;
    await _applyWakelock();
    notifyListeners();
  }

  Future<void> setReferenceA4(double hz) async {
    final next = hz.clamp(minA4, maxA4).toDouble();
    if (next == _referenceA4) return;
    _referenceA4 = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRefA4, _referenceA4);
  }

  void nudgeReferenceA4(double delta) => setReferenceA4(_referenceA4 + delta);

  Future<void> setSpectrogramSensitivity(double value) async {
    final next = value.clamp(0.0, 1.0);
    if (next == _spectrogramSensitivity) return;
    _spectrogramSensitivity = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSensitivity, _spectrogramSensitivity);
  }

  Future<void> setKeepAwake(bool value) async {
    if (value == _keepAwake) return;
    _keepAwake = value;
    notifyListeners();
    await _applyWakelock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKeepAwake, value);
  }

  Future<void> _applyWakelock() async {
    try {
      await WakelockPlus.toggle(enable: _keepAwake);
    } catch (_) {
      // Best-effort: some platforms require a user gesture or lack support.
    }
  }
}
