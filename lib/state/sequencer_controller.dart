import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/sequencer_engine.dart';
import '../models/sequencer_pattern.dart';
import '../services/synth_audio.dart';

/// View-model for the step sequencer. Owns the [SequencerPattern], the
/// [SequencerEngine] clock, and the [SynthAudio] voices: on each step boundary
/// it triggers the active drums/bass/chord, publishes the playhead through
/// [currentStep], and persists edits.
///
/// Tempo follows the metronome's BPM by default ([setFollowedBpm]); the pattern
/// may override it. The sequencer keeps its own transport, so it can loop a
/// backing track independently of the metronome.
class SequencerController extends ChangeNotifier {
  SequencerController({SynthAudio? audio}) : _audio = audio ?? SynthAudio() {
    _engine = SequencerEngine(onStep: _onStep);
  }

  static const _prefsKey = 'metro_power.sequencer_pattern';

  final SynthAudio _audio;
  late final SequencerEngine _engine;

  SequencerPattern _pattern = SequencerPattern.empty();
  bool _isPlaying = false;
  bool _initialized = false;
  double _followedBpm = 120;

  /// The currently sounding step (−1 when stopped), for playhead highlighting.
  final ValueNotifier<int> currentStep = ValueNotifier(-1);

  SequencerPattern get pattern => _pattern;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _initialized;
  bool get followsMetronome => _pattern.bpmOverride == null;
  double get effectiveBpm => _pattern.bpmOverride ?? _followedBpm;

  Future<void> init() async {
    await _audio.init();
    final saved = await _load();
    if (saved != null) _pattern = saved;
    await _audio.setKey(_pattern.root, _pattern.scale);
    _engine.configure(
      bpm: effectiveBpm,
      steps: _pattern.steps,
      stepsPerBeat: _pattern.stepsPerBeat,
    );
    _initialized = true;
    notifyListeners();
  }

  /// Push the metronome's tempo; only affects playback while following.
  void setFollowedBpm(double bpm) {
    if (bpm <= 0 || bpm == _followedBpm) return;
    _followedBpm = bpm;
    if (followsMetronome) {
      _engine.configure(bpm: effectiveBpm);
      notifyListeners();
    }
  }

  void _onStep(int step) {
    currentStep.value = step;
    final p = _pattern;
    for (final k in DrumKind.values) {
      if (p.drumMute[k] != true && p.drums[k]![step]) {
        _audio.playDrum(k, p.drumVol[k] ?? 0.9);
      }
    }
    if (!p.bassMute) {
      final row = p.bass[step];
      if (row != null) _audio.playBass(row, p.bassVol);
    }
    if (!p.chordMute) {
      final degree = p.chords[step];
      if (degree != null) _audio.playChord(degree, p.chordVol);
    }
  }

  // --- transport ---------------------------------------------------------

  void toggle() => _isPlaying ? stop() : start();

  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _engine.configure(
      bpm: effectiveBpm,
      steps: _pattern.steps,
      stepsPerBeat: _pattern.stepsPerBeat,
    );
    _engine.start();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _engine.stop();
    currentStep.value = -1;
    notifyListeners();
  }

  // --- edits -------------------------------------------------------------

  void _apply(SequencerPattern next,
      {bool reconfigure = false, bool rekey = false}) {
    _pattern = next;
    if (reconfigure) {
      _engine.configure(
        bpm: effectiveBpm,
        steps: next.steps,
        stepsPerBeat: next.stepsPerBeat,
      );
    }
    if (rekey) _audio.setKey(next.root, next.scale);
    _save();
    notifyListeners();
  }

  void toggleDrum(DrumKind kind, int step) {
    final grid = List<bool>.from(_pattern.drums[kind]!);
    grid[step] = !grid[step];
    final drums = Map<DrumKind, List<bool>>.from(_pattern.drums);
    drums[kind] = grid;
    _apply(_pattern.copyWith(drums: drums));
  }

  /// Set the bass note row at [step] (null = rest). Monophonic.
  void setBass(int step, int? row) {
    final bass = List<int?>.from(_pattern.bass);
    bass[step] = row;
    _apply(_pattern.copyWith(bass: bass));
  }

  /// Set the chord degree at [step] (null = rest). Monophonic.
  void setChord(int step, int? degree) {
    final chords = List<int?>.from(_pattern.chords);
    chords[step] = degree;
    _apply(_pattern.copyWith(chords: chords));
  }

  void setSteps(int steps) {
    if (steps == _pattern.steps) return;
    List<bool> rb(List<bool> s) =>
        List<bool>.generate(steps, (i) => i < s.length && s[i]);
    List<int?> ri(List<int?> s) =>
        List<int?>.generate(steps, (i) => i < s.length ? s[i] : null);
    final drums = {
      for (final k in DrumKind.values) k: rb(_pattern.drums[k]!),
    };
    _apply(
      _pattern.copyWith(
        steps: steps,
        drums: drums,
        bass: ri(_pattern.bass),
        chords: ri(_pattern.chords),
      ),
      reconfigure: true,
    );
  }

  void setRoot(int root) =>
      _apply(_pattern.copyWith(root: root.clamp(0, 11)), rekey: true);

  void setScale(SynthScale scale) =>
      _apply(_pattern.copyWith(scale: scale), rekey: true);

  /// Set an explicit tempo, or pass null to follow the metronome again.
  void setBpmOverride(double? bpm) => _apply(
        _pattern.copyWith(bpmOverride: bpm?.clamp(20, 400)),
        reconfigure: true,
      );

  void setDrumVolume(DrumKind kind, double volume) {
    final vol = Map<DrumKind, double>.from(_pattern.drumVol);
    vol[kind] = volume.clamp(0.0, 1.0);
    _apply(_pattern.copyWith(drumVol: vol));
  }

  void toggleDrumMute(DrumKind kind) {
    final mute = Map<DrumKind, bool>.from(_pattern.drumMute);
    mute[kind] = !(mute[kind] ?? false);
    _apply(_pattern.copyWith(drumMute: mute));
  }

  void setBassVolume(double v) => _apply(_pattern.copyWith(bassVol: v.clamp(0.0, 1.0)));
  void toggleBassMute() => _apply(_pattern.copyWith(bassMute: !_pattern.bassMute));
  void setChordVolume(double v) =>
      _apply(_pattern.copyWith(chordVol: v.clamp(0.0, 1.0)));
  void toggleChordMute() =>
      _apply(_pattern.copyWith(chordMute: !_pattern.chordMute));

  void clear() => _apply(
        SequencerPattern.empty(steps: _pattern.steps).copyWith(
          root: _pattern.root,
          scale: _pattern.scale,
          bpmOverride: _pattern.bpmOverride,
        ),
        reconfigure: true,
      );

  // --- persistence -------------------------------------------------------

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_pattern.toJson()));
  }

  Future<SequencerPattern?> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      return SequencerPattern.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    _audio.dispose();
    currentStep.dispose();
    super.dispose();
  }
}
