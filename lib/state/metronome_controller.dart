import 'package:flutter/foundation.dart';

import '../engine/metronome_engine.dart';
import '../engine/tick_event.dart';
import '../models/accent.dart';
import '../models/metronome_state.dart';
import '../models/poly_timbre.dart';
import '../models/preset.dart';
import '../models/subdivision.dart';
import '../models/trainer_config.dart';
import '../services/audio_clicks.dart';
import '../services/preset_store.dart';

/// The app's central view-model. Owns the [MetronomeEngine], wires its ticks to
/// the [AudioClicks] service, exposes the current [MetronomeState] plus simple
/// mutators for the UI, and persists changes through [PresetStore].
///
/// Settings changes notify listeners (rebuild the controls). Per-tick beat
/// highlighting is published separately through [pulse] so the 4 ms tick stream
/// does not rebuild the whole widget tree.
class MetronomeController extends ChangeNotifier {
  MetronomeController({
    AudioClicks? audio,
    PresetStore? store,
    MetronomeState? initial,
  })  : _audio = audio ?? AudioClicks(),
        _store = store ?? PresetStore(),
        _state = initial ?? const MetronomeState() {
    _engine = MetronomeEngine(
      state: _state,
      onTick: _onTick,
      onBpmChanged: _onBpmChanged,
    );
  }

  final AudioClicks _audio;
  final PresetStore _store;
  late final MetronomeEngine _engine;

  MetronomeState _state;
  bool _isPlaying = false;
  bool _initialized = false;
  final List<DateTime> _taps = [];
  List<Preset> _presets = [];

  /// Latest tick, for beat-grid highlighting. Null while stopped.
  final ValueNotifier<TickEvent?> pulse = ValueNotifier(null);

  MetronomeState get state => _state;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _initialized;
  List<Preset> get presets => List.unmodifiable(_presets);

  Future<void> init() async {
    await _audio.init();
    _presets = await _store.loadPresets();
    final saved = await _store.loadLast();
    if (saved != null) {
      _state = saved;
      _engine.updateState(_state);
    }
    _initialized = true;
    notifyListeners();
  }

  void _onTick(TickEvent event, bool audible) {
    if (audible) {
      if (event.isPoly) {
        _audio.playPoly(
          _state.polyTimbre,
          event.type == ClickType.polyStrong,
          _state.polyVolume,
        );
      } else {
        _audio.play(event.type);
      }
    }
    pulse.value = event;
  }

  void _onBpmChanged(double bpm) {
    _state = _state.copyWith(bpm: bpm);
    _store.saveLast(_state);
    notifyListeners();
  }

  void _apply(MetronomeState next) {
    _state = next;
    _engine.updateState(next);
    _store.saveLast(next);
    notifyListeners();
  }

  // --- Transport ---------------------------------------------------------

  void toggle() => _isPlaying ? stop() : start();

  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _engine.start();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _engine.stop();
    pulse.value = null;
    notifyListeners();
  }

  // --- Tempo -------------------------------------------------------------

  void setBpm(double bpm) => _apply(_state.copyWith(bpm: bpm.clamp(20, 400)));

  void nudgeBpm(double delta) => setBpm(_state.bpm + delta);

  /// Register a tap; once two or more taps land within the rolling window the
  /// averaged interval sets the tempo.
  void tap() {
    final now = DateTime.now();
    _taps.add(now);
    _taps.removeWhere((t) => now.difference(t).inMilliseconds > 2500);
    if (_taps.length >= 2) {
      var total = 0;
      for (var i = 1; i < _taps.length; i++) {
        total += _taps[i].difference(_taps[i - 1]).inMilliseconds;
      }
      final avg = total / (_taps.length - 1);
      if (avg > 0) setBpm(60000 / avg);
    }
  }

  // --- Meter & accents ---------------------------------------------------

  void setBeats(int beats) {
    final clamped = beats.clamp(1, 16);
    final accents = List<AccentLevel>.generate(
      clamped,
      (i) => i < _state.accents.length
          ? _state.accents[i]
          : (i == 0 ? AccentLevel.strong : AccentLevel.normal),
    );
    _apply(_state.copyWith(
      timeSignature: _state.timeSignature.copyWith(beats: clamped),
      accents: accents,
    ));
  }

  void setUnit(int unit) =>
      _apply(_state.copyWith(timeSignature: _state.timeSignature.copyWith(unit: unit)));

  /// Cycle a beat's accent strong → normal → weak → mute → strong.
  void cycleAccent(int beat) {
    if (beat < 0 || beat >= _state.accents.length) return;
    const order = [
      AccentLevel.strong,
      AccentLevel.normal,
      AccentLevel.weak,
      AccentLevel.mute,
    ];
    final accents = List<AccentLevel>.from(_state.accents);
    final current = order.indexOf(accents[beat]);
    accents[beat] = order[(current + 1) % order.length];
    _apply(_state.copyWith(accents: accents));
  }

  void setSubdivision(Subdivision subdivision) =>
      _apply(_state.copyWith(subdivision: subdivision));

  // --- Polyrhythm --------------------------------------------------------

  void setPolyEnabled(bool enabled) =>
      _apply(_state.copyWith(polyEnabled: enabled));

  void setPolyPulses(int pulses) =>
      _apply(_state.copyWith(polyPulses: pulses.clamp(2, 12)));

  void setPolyTimbre(PolyTimbre timbre) =>
      _apply(_state.copyWith(polyTimbre: timbre));

  void setPolyVolume(double volume) =>
      _apply(_state.copyWith(polyVolume: volume.clamp(0.0, 1.0)));

  // --- Trainer -----------------------------------------------------------

  void setTrainer(TrainerConfig trainer) =>
      _apply(_state.copyWith(trainer: trainer));

  // --- Presets / setlist -------------------------------------------------

  Future<void> savePreset(String name) async {
    final preset = Preset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Untitled' : name.trim(),
      state: _state,
    );
    _presets = [..._presets, preset];
    await _store.savePresets(_presets);
    notifyListeners();
  }

  Future<void> deletePreset(String id) async {
    _presets = _presets.where((p) => p.id != id).toList();
    await _store.savePresets(_presets);
    notifyListeners();
  }

  void loadPreset(Preset preset) => _apply(preset.state);

  @override
  void dispose() {
    _engine.dispose();
    _audio.dispose();
    pulse.dispose();
    super.dispose();
  }
}
