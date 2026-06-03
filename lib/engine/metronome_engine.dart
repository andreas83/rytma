import 'dart:async';

import '../models/accent.dart';
import '../models/metronome_state.dart';
import 'tick_event.dart';

typedef TickCallback = void Function(TickEvent event, bool audible);
typedef BpmCallback = void Function(double bpm);
typedef BarCallback = void Function(int bar);

/// Drives metronome timing.
///
/// The engine pre-computes the ordered list of [TickEvent]s for a single bar
/// (primary voice + optional polyrhythm voice). A high-resolution [Stopwatch]
/// is the authoritative clock; a short periodic [Timer] polls it and fires
/// every event whose scheduled time has elapsed. Because the loop start time is
/// advanced by exact bar durations, timing does not drift even though the poll
/// timer itself is coarse.
///
/// The engine is UI-framework agnostic: it only emits callbacks. Audio
/// playback and widget updates are the controller's responsibility.
class MetronomeEngine {
  MetronomeEngine({
    required MetronomeState state,
    required this.onTick,
    this.onBpmChanged,
    this.onBar,
    // ignore: prefer_initializing_formals
  }) : _state = state {
    _rebuild();
  }

  final TickCallback onTick;
  final BpmCallback? onBpmChanged;
  final BarCallback? onBar;

  static const int _pollIntervalMs = 4;
  static const int _maxEventsPerPoll = 512;

  MetronomeState _state;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;

  List<TickEvent> _events = const [];
  double _barDurationMs = 0;
  double _loopStartMs = 0;
  int _nextIndex = 0;
  int _barCount = 0;
  bool _running = false;

  bool get isRunning => _running;
  int get barCount => _barCount;
  double get barDurationMs => _barDurationMs;

  /// Time remaining until the next bar boundary, for transport-synced features
  /// (e.g. the looper). Zero when stopped.
  Duration get timeToNextBar {
    if (!_running || _barDurationMs <= 0) return Duration.zero;
    final nowMs = _clock.elapsedMicroseconds / 1000.0;
    final remaining =
        (_barDurationMs - (nowMs - _loopStartMs)).clamp(0.0, _barDurationMs);
    return Duration(microseconds: (remaining * 1000).round());
  }

  /// Replace the active settings; safe to call while running.
  void updateState(MetronomeState state) {
    _state = state;
    _rebuild();
  }

  void start() {
    if (_running) return;
    _running = true;
    _barCount = 0;
    _nextIndex = 0;
    _loopStartMs = 0;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _dispatch(),
    );
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void dispose() => stop();

  /// Build the ordered event schedule for one bar from the current state.
  void _rebuild() {
    final beats = _state.timeSignature.beats;
    final beatMs = 60000.0 / _state.bpm;
    _barDurationMs = beats * beatMs;

    final events = <TickEvent>[];
    final subs = _state.subdivision.pulses;

    // Primary voice: each beat, divided into [subs] evenly spaced clicks.
    for (var b = 0; b < beats; b++) {
      final beatStart = b * beatMs;
      final accent =
          b < _state.accents.length ? _state.accents[b] : AccentLevel.normal;
      for (var s = 0; s < subs; s++) {
        final t = beatStart + s * (beatMs / subs);
        final ClickType type;
        if (s == 0) {
          type = _accentClick(accent);
        } else {
          type = accent == AccentLevel.mute ? ClickType.mute : ClickType.sub;
        }
        events.add(TickEvent(
          timeMs: t,
          type: type,
          voice: 0,
          beat: b,
          sub: s,
        ));
      }
    }

    // Polyrhythm voice: [polyPulses] evenly spaced across the whole bar.
    if (_state.polyEnabled && _state.polyPulses > 1) {
      final p = _state.polyPulses;
      for (var i = 0; i < p; i++) {
        events.add(TickEvent(
          timeMs: i * (_barDurationMs / p),
          type: i == 0 ? ClickType.polyStrong : ClickType.polyWeak,
          voice: 1,
          beat: i,
          sub: 0,
        ));
      }
    }

    events.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _events = events;
    if (_nextIndex > _events.length) _nextIndex = 0;
  }

  ClickType _accentClick(AccentLevel accent) {
    switch (accent) {
      case AccentLevel.strong:
        return ClickType.strong;
      case AccentLevel.normal:
        return ClickType.normal;
      case AccentLevel.weak:
        return ClickType.weak;
      case AccentLevel.mute:
        return ClickType.mute;
    }
  }

  /// Whether the given bar should be audible under the gap trainer.
  bool _audibleForBar(int bar) {
    final t = _state.trainer;
    if (!t.gapEnabled) return true;
    final cycle = t.gapPlayBars + t.gapMuteBars;
    if (cycle <= 0) return true;
    return (bar % cycle) < t.gapPlayBars;
  }

  void _dispatch() {
    if (!_running || _events.isEmpty) return;
    final now = _clock.elapsedMicroseconds / 1000.0;

    var guard = 0;
    while (_running && guard < _maxEventsPerPoll) {
      guard++;
      if (_nextIndex >= _events.length) {
        // Bar complete: advance the loop by an exact bar and apply trainers.
        _loopStartMs += _barDurationMs;
        _nextIndex = 0;
        _barCount++;
        _handleBarBoundary();
        if (_events.isEmpty) return;
        continue;
      }
      final event = _events[_nextIndex];
      final due = _loopStartMs + event.timeMs;
      if (due <= now) {
        onTick(event, _audibleForBar(_barCount));
        _nextIndex++;
      } else {
        break;
      }
    }
  }

  void _handleBarBoundary() {
    onBar?.call(_barCount);

    final t = _state.trainer;
    if (t.tempoRampEnabled &&
        t.rampEveryBars > 0 &&
        _barCount % t.rampEveryBars == 0) {
      final goingUp = t.rampTargetBpm >= _state.bpm;
      var next = _state.bpm + (goingUp ? t.rampStepBpm : -t.rampStepBpm);
      final target = t.rampTargetBpm.toDouble();
      if (goingUp && next > target) next = target;
      if (!goingUp && next < target) next = target;
      if (next != _state.bpm) {
        _state = _state.copyWith(bpm: next);
        _rebuild();
        onBpmChanged?.call(next);
      }
    }
  }
}
