import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/sequencer_engine.dart';
import '../models/fx_settings.dart';
import '../models/sequencer_pattern.dart';
import '../models/sequencer_song.dart';
import '../services/synth_audio.dart';

/// View-model for the step sequencer. Owns a [SequencerSong] (a bank of
/// [SequencerPattern]s + an arrangement), the [SequencerEngine] clock, and the
/// [SynthAudio] voices: on each step boundary it triggers the active pattern's
/// drums/bass/chord/lead, publishes the playhead through [currentStep], and
/// persists edits.
///
/// The bank's key / scale / waveforms / swing / tempo are kept in sync across
/// all patterns, so switching patterns during a song never re-renders voices
/// (no audio glitch). Tempo follows the metronome's BPM unless overridden. The
/// sequencer keeps its own transport.
class SequencerController extends ChangeNotifier {
  SequencerController({SynthAudio? audio}) : _audio = audio ?? SynthAudio() {
    _engine = SequencerEngine(onStep: _onStep);
  }

  static const _legacyKey = 'rytma.sequencer_pattern';
  static const _songKey = 'rytma.sequencer_song';
  static const _fxKey = 'rytma.sequencer_fx';

  final SynthAudio _audio;
  late final SequencerEngine _engine;
  final Random _rng = Random();

  SequencerSong _song = SequencerSong.single(SequencerPattern.empty());
  FxSettings _fx = const FxSettings();
  int _editIndex = 0;
  bool _songMode = false;
  bool _isPlaying = false;
  bool _initialized = false;
  double _followedBpm = 120;

  // Song-arrangement playback cursor.
  int _arrIndex = 0;
  int _repeatLeft = 1;
  bool _loopStarted = false;

  /// The currently sounding step (−1 when stopped), for playhead highlighting.
  final ValueNotifier<int> currentStep = ValueNotifier(-1);

  // --- active pattern (bank-backed) --------------------------------------

  int get _activeIndex {
    final i = (_songMode && _isPlaying)
        ? _song.arrangement[_arrIndex].patternIndex
        : _editIndex;
    return i.clamp(0, _song.bank.length - 1);
  }

  SequencerPattern get _pattern => _song.bank[_activeIndex];
  set _pattern(SequencerPattern p) {
    final bank = List<SequencerPattern>.from(_song.bank);
    bank[_activeIndex] = p;
    _song = _song.copyWith(bank: bank);
  }

  // --- public state ------------------------------------------------------

  SequencerPattern get pattern => _pattern;
  FxSettings get fx => _fx;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _initialized;
  bool get followsMetronome => _pattern.bpmOverride == null;
  double get effectiveBpm => _pattern.bpmOverride ?? _followedBpm;

  bool get songMode => _songMode;
  int get patternCount => _song.bank.length;
  int get editIndex => _editIndex;
  List<ArrangementStep> get arrangement =>
      List.unmodifiable(_song.arrangement);

  /// Arrangement step currently playing (−1 when not playing a song).
  int get playingArrangement => (_songMode && _isPlaying) ? _arrIndex : -1;

  /// Bank pattern index currently sounding/edited (for chip highlighting).
  int get activePatternIndex => _activeIndex;

  Future<void> init() async {
    await _audio.init();
    _song = await _loadSong() ?? SequencerSong.single(SequencerPattern.empty());
    _fx = await _loadFx() ?? const FxSettings();
    await _pushVoices();
    _audio.applyFx(_fx);
    _reconfigure();
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

  void _reconfigure() => _engine.configure(
        bpm: effectiveBpm,
        steps: _pattern.steps,
        stepsPerBeat: _pattern.stepsPerBeat,
        swing: _pattern.swing,
      );

  /// Roll a step's probability dice (always true at 1.0).
  bool _hit(double prob) => prob >= 1.0 || _rng.nextDouble() < prob;

  void _onStep(int step) {
    if (step == 0) {
      if (_loopStarted && _songMode) _advanceSong();
      _loopStarted = true;
    }
    currentStep.value = step;
    final p = _pattern;
    for (final k in DrumKind.values) {
      if (p.drumMute[k] != true &&
          p.drums[k]![step] &&
          _hit(p.drumProb[k]![step])) {
        _audio.playDrum(k, (p.drumVol[k] ?? 0.9) * p.drumVelocity[k]![step].gain);
      }
    }
    if (!p.bassMute) {
      final row = p.bass[step];
      if (row != null && _hit(p.bassProb[step])) {
        _audio.playBass(row, p.bassVol * p.bassVelocity[step].gain);
      }
    }
    if (!p.chordMute) {
      final degree = p.chords[step];
      if (degree != null && _hit(p.chordProb[step])) {
        _audio.playChord(degree, p.chordVol * p.chordVelocity[step].gain);
      }
    }
    if (!p.leadMute) {
      final row = p.lead[step];
      if (row != null && _hit(p.leadProb[step])) {
        _audio.playLead(row, p.leadVol * p.leadVelocity[step].gain);
      }
    }
  }

  /// Advance the arrangement at a loop boundary. Voices are shared across the
  /// bank, so this only re-times the engine for the new pattern length — no
  /// re-render, so the switch is glitch-free.
  void _advanceSong() {
    final arr = _song.arrangement;
    _repeatLeft -= 1;
    if (_repeatLeft <= 0) {
      _arrIndex = (_arrIndex + 1) % arr.length;
      _repeatLeft = arr[_arrIndex].repeats;
    }
    final p = _pattern; // uses the new _arrIndex
    _engine.configure(steps: p.steps, swing: p.swing, bpm: effectiveBpm);
    notifyListeners();
  }

  Future<void> _pushVoices() => _audio.setVoices(
        _pattern.root,
        _pattern.scale,
        bassWave: _pattern.bassWave,
        chordWave: _pattern.chordWave,
        leadWave: _pattern.leadWave,
      );

  // --- transport ---------------------------------------------------------

  void toggle() => _isPlaying ? stop() : start();

  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _loopStarted = false;
    if (_songMode) {
      _arrIndex = 0;
      _repeatLeft = _song.arrangement.first.repeats;
    }
    _reconfigure();
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

  // --- edits (target the active pattern) ---------------------------------

  void _apply(SequencerPattern next,
      {bool reconfigure = false, bool rekey = false}) {
    _pattern = next;
    if (reconfigure) _reconfigure();
    if (rekey) _pushVoices();
    _save();
    notifyListeners();
  }

  /// Map an edit across **every** bank pattern (for shared key/scale/wave/swing/
  /// tempo), preserving the no-glitch invariant.
  void _applyShared(SequencerPattern Function(SequencerPattern) f,
      {bool reconfigure = false, bool rekey = false}) {
    _song = _song.copyWith(bank: [for (final p in _song.bank) f(p)]);
    if (reconfigure) _reconfigure();
    if (rekey) _pushVoices();
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

  /// Set the lead note row at [step] (null = rest). Monophonic.
  void setLead(int step, int? row) {
    final lead = List<int?>.from(_pattern.lead);
    lead[step] = row;
    _apply(_pattern.copyWith(lead: lead));
  }

  void setSteps(int steps) {
    if (steps == _pattern.steps) return;
    List<bool> rb(List<bool> s) =>
        List<bool>.generate(steps, (i) => i < s.length && s[i]);
    List<int?> ri(List<int?> s) =>
        List<int?>.generate(steps, (i) => i < s.length ? s[i] : null);
    List<StepVelocity> rv(List<StepVelocity> s) => List<StepVelocity>.generate(
        steps, (i) => i < s.length ? s[i] : StepVelocity.normal);
    List<double> rp(List<double> s) =>
        List<double>.generate(steps, (i) => i < s.length ? s[i] : 1.0);
    final drums = {for (final k in DrumKind.values) k: rb(_pattern.drums[k]!)};
    final drumVelocity = {
      for (final k in DrumKind.values) k: rv(_pattern.drumVelocity[k]!),
    };
    final drumProb = {
      for (final k in DrumKind.values) k: rp(_pattern.drumProb[k]!),
    };
    _apply(
      _pattern.copyWith(
        steps: steps,
        drums: drums,
        bass: ri(_pattern.bass),
        chords: ri(_pattern.chords),
        lead: ri(_pattern.lead),
        drumVelocity: drumVelocity,
        bassVelocity: rv(_pattern.bassVelocity),
        chordVelocity: rv(_pattern.chordVelocity),
        leadVelocity: rv(_pattern.leadVelocity),
        drumProb: drumProb,
        bassProb: rp(_pattern.bassProb),
        chordProb: rp(_pattern.chordProb),
        leadProb: rp(_pattern.leadProb),
      ),
      reconfigure: true,
    );
  }

  // Key / scale / waveform / swing / tempo are shared across the bank.

  void setRoot(int root) =>
      _applyShared((p) => p.copyWith(root: root.clamp(0, 11)), rekey: true);

  void setScale(SynthScale scale) =>
      _applyShared((p) => p.copyWith(scale: scale), rekey: true);

  /// Set an explicit tempo, or pass null to follow the metronome again.
  void setBpmOverride(double? bpm) => _applyShared(
        (p) => p.copyWith(bpmOverride: bpm?.clamp(20, 400)),
        reconfigure: true,
      );

  void setBassWave(SynthWave wave) =>
      _applyShared((p) => p.copyWith(bassWave: wave), rekey: true);
  void setChordWave(SynthWave wave) =>
      _applyShared((p) => p.copyWith(chordWave: wave), rekey: true);
  void setLeadWave(SynthWave wave) =>
      _applyShared((p) => p.copyWith(leadWave: wave), rekey: true);

  void setSwing(double swing) => _applyShared(
        (p) => p.copyWith(swing: swing.clamp(0.0, 0.5)),
        reconfigure: true,
      );

  // Mix is per-pattern.

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
  void setLeadVolume(double v) =>
      _apply(_pattern.copyWith(leadVol: v.clamp(0.0, 1.0)));
  void toggleLeadMute() => _apply(_pattern.copyWith(leadMute: !_pattern.leadMute));

  void clear() => _apply(
        SequencerPattern.empty(steps: _pattern.steps).copyWith(
          root: _pattern.root,
          scale: _pattern.scale,
          bassWave: _pattern.bassWave,
          chordWave: _pattern.chordWave,
          leadWave: _pattern.leadWave,
          swing: _pattern.swing,
          bpmOverride: _pattern.bpmOverride,
        ),
        reconfigure: true,
      );

  // --- groove (per-step velocity + probability) --------------------------

  void setDrumVelocity(DrumKind kind, int step, StepVelocity v) {
    final list = List<StepVelocity>.from(_pattern.drumVelocity[kind]!);
    list[step] = v;
    final map = Map<DrumKind, List<StepVelocity>>.from(_pattern.drumVelocity);
    map[kind] = list;
    _apply(_pattern.copyWith(drumVelocity: map));
  }

  void setDrumProbability(DrumKind kind, int step, double p) {
    final list = List<double>.from(_pattern.drumProb[kind]!);
    list[step] = p.clamp(0.0, 1.0);
    final map = Map<DrumKind, List<double>>.from(_pattern.drumProb);
    map[kind] = list;
    _apply(_pattern.copyWith(drumProb: map));
  }

  void setBassVelocity(int step, StepVelocity v) => _apply(
      _pattern.copyWith(bassVelocity: _withVel(_pattern.bassVelocity, step, v)));
  void setChordVelocity(int step, StepVelocity v) => _apply(_pattern.copyWith(
      chordVelocity: _withVel(_pattern.chordVelocity, step, v)));
  void setLeadVelocity(int step, StepVelocity v) => _apply(
      _pattern.copyWith(leadVelocity: _withVel(_pattern.leadVelocity, step, v)));

  void setBassProbability(int step, double p) => _apply(
      _pattern.copyWith(bassProb: _withProb(_pattern.bassProb, step, p)));
  void setChordProbability(int step, double p) => _apply(
      _pattern.copyWith(chordProb: _withProb(_pattern.chordProb, step, p)));
  void setLeadProbability(int step, double p) => _apply(
      _pattern.copyWith(leadProb: _withProb(_pattern.leadProb, step, p)));

  List<StepVelocity> _withVel(List<StepVelocity> src, int step, StepVelocity v) {
    final list = List<StepVelocity>.from(src);
    list[step] = v;
    return list;
  }

  List<double> _withProb(List<double> src, int step, double p) {
    final list = List<double>.from(src);
    list[step] = p.clamp(0.0, 1.0);
    return list;
  }

  // --- song mode (bank + arrangement) ------------------------------------

  void setSongMode(bool on) {
    if (_songMode == on) return;
    _songMode = on;
    if (_isPlaying) {
      if (on) {
        _arrIndex = 0;
        _repeatLeft = _song.arrangement.first.repeats;
        _loopStarted = false;
      }
      _reconfigure();
    }
    _save();
    notifyListeners();
  }

  void selectPattern(int index) {
    if (index < 0 || index >= _song.bank.length || index == _editIndex) return;
    _editIndex = index;
    if (!(_songMode && _isPlaying)) _reconfigure();
    notifyListeners();
  }

  void addPattern() {
    if (_song.bank.length >= SequencerSong.maxPatterns) return;
    final base = _song.bank[_editIndex];
    final fresh = SequencerPattern.empty(steps: base.steps).copyWith(
      root: base.root,
      scale: base.scale,
      bassWave: base.bassWave,
      chordWave: base.chordWave,
      leadWave: base.leadWave,
      swing: base.swing,
      bpmOverride: base.bpmOverride,
    );
    _song = _song.copyWith(bank: [..._song.bank, fresh]);
    _editIndex = _song.bank.length - 1;
    if (!(_songMode && _isPlaying)) _reconfigure();
    _save();
    notifyListeners();
  }

  void duplicatePattern() {
    if (_song.bank.length >= SequencerSong.maxPatterns) return;
    // Deep copy via JSON so the new slot shares no mutable lists.
    final copy =
        SequencerPattern.fromJson(_song.bank[_editIndex].toJson());
    _song = _song.copyWith(bank: [..._song.bank, copy]);
    _editIndex = _song.bank.length - 1;
    _save();
    notifyListeners();
  }

  void deletePattern(int index) {
    if (_song.bank.length <= 1 || index < 0 || index >= _song.bank.length) {
      return;
    }
    final bank = List<SequencerPattern>.from(_song.bank)..removeAt(index);
    // Drop arrangement steps that referenced it; renumber higher indices.
    var arr = _song.arrangement
        .where((a) => a.patternIndex != index)
        .map((a) => a.patternIndex > index
            ? a.copyWith(patternIndex: a.patternIndex - 1)
            : a)
        .toList();
    if (arr.isEmpty) arr = [const ArrangementStep(patternIndex: 0)];
    _song = SequencerSong(bank: bank, arrangement: arr);
    _editIndex = _editIndex.clamp(0, bank.length - 1);
    if (_arrIndex >= arr.length) _arrIndex = 0;
    if (!(_songMode && _isPlaying)) _reconfigure();
    _save();
    notifyListeners();
  }

  void addArrangementStep(int patternIndex) {
    final arr = [
      ..._song.arrangement,
      ArrangementStep(patternIndex: patternIndex.clamp(0, _song.bank.length - 1)),
    ];
    _song = _song.copyWith(arrangement: arr);
    _save();
    notifyListeners();
  }

  void removeArrangementStep(int index) {
    if (_song.arrangement.length <= 1) return;
    final arr = List<ArrangementStep>.from(_song.arrangement)..removeAt(index);
    _song = _song.copyWith(arrangement: arr);
    if (_arrIndex >= arr.length) _arrIndex = 0;
    _save();
    notifyListeners();
  }

  void setArrangementRepeats(int index, int repeats) {
    final arr = List<ArrangementStep>.from(_song.arrangement);
    arr[index] = arr[index].copyWith(repeats: repeats.clamp(1, 16));
    _song = _song.copyWith(arrangement: arr);
    _save();
    notifyListeners();
  }

  // --- FX rack -----------------------------------------------------------

  void _applyFx(FxSettings next) {
    _fx = next;
    _audio.applyFx(_fx);
    _saveFx();
    notifyListeners();
  }

  void toggleReverb() => _applyFx(_fx.copyWith(reverbOn: !_fx.reverbOn));
  void setReverbWet(double v) => _applyFx(_fx.copyWith(reverbWet: v));
  void setReverbRoom(double v) => _applyFx(_fx.copyWith(reverbRoom: v));
  void toggleEcho() => _applyFx(_fx.copyWith(echoOn: !_fx.echoOn));
  void setEchoWet(double v) => _applyFx(_fx.copyWith(echoWet: v));
  void setEchoDelay(double v) => _applyFx(_fx.copyWith(echoDelay: v));
  void setEchoDecay(double v) => _applyFx(_fx.copyWith(echoDecay: v));
  void toggleLpf() => _applyFx(_fx.copyWith(lpfOn: !_fx.lpfOn));
  void setLpfCutoff(double v) => _applyFx(_fx.copyWith(lpfCutoff: v));
  void setLpfResonance(double v) => _applyFx(_fx.copyWith(lpfResonance: v));
  void toggleComp() => _applyFx(_fx.copyWith(compOn: !_fx.compOn));

  // --- persistence -------------------------------------------------------

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_songKey, jsonEncode(_song.toJson()));
  }

  Future<void> _saveFx() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fxKey, jsonEncode(_fx.toJson()));
  }

  Future<FxSettings?> _loadFx() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_fxKey);
    if (raw == null) return null;
    try {
      return FxSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<SequencerSong?> _loadSong() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_songKey);
    if (raw != null) {
      try {
        return SequencerSong.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // fall through to legacy migration
      }
    }
    // Migrate a legacy single-pattern save into a one-pattern song.
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        return SequencerSong.single(
          SequencerPattern.fromJson(jsonDecode(legacy) as Map<String, dynamic>),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _engine.dispose();
    _audio.dispose();
    currentStep.dispose();
    super.dispose();
  }
}
