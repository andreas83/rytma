import 'dart:async';

/// Drives the step sequencer's timing.
///
/// Like [MetronomeEngine], a high-resolution [Stopwatch] is the authoritative
/// clock and a short periodic [Timer] polls it, firing every step whose time
/// has elapsed. The loop start advances by exact loop durations so playback
/// does not drift. The engine only emits [onStep] callbacks — sound and UI are
/// the controller's job — so it stays framework-agnostic and unit-testable.
class SequencerEngine {
  SequencerEngine({required this.onStep});

  /// Called on each step boundary with the step index (0.._steps-1).
  final void Function(int step) onStep;

  static const int _pollMs = 4;
  static const int _maxStepsPerPoll = 64;

  double _bpm = 120;
  int _steps = 16;
  int _stepsPerBeat = 4; // sixteenth-note grid
  double _swing = 0; // fraction of a step the off-beats are delayed

  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  double _stepMs = 125;
  double _loopStartMs = 0;
  int _next = 0;
  bool _running = false;

  bool get isRunning => _running;
  double get stepMs => _stepMs;

  /// Offset of [step] from the loop start (ms), including swing. Off-beats (odd
  /// steps) are delayed by up to half a step, which keeps offsets monotonic (an
  /// off-beat never reaches its following on-beat). Exposed for testing.
  double stepOffsetMs(int step) =>
      step * _stepMs + (step.isOdd ? _swing * _stepMs : 0.0);

  /// The scheduled time of [step] within the current loop, including swing.
  double _dueFor(int step) => _loopStartMs + stepOffsetMs(step);

  /// Update tempo / grid / swing; safe to call while running. When running, the
  /// loop is re-anchored to *now* so the current step boundary stays continuous
  /// and a tempo change doesn't cause a burst or gap.
  void configure({double? bpm, int? steps, int? stepsPerBeat, double? swing}) {
    if (bpm != null && bpm > 0) _bpm = bpm;
    if (steps != null && steps > 0) _steps = steps;
    if (stepsPerBeat != null && stepsPerBeat > 0) _stepsPerBeat = stepsPerBeat;
    if (swing != null) _swing = swing.clamp(0.0, 0.5);
    final newStepMs = 60000.0 / _bpm / _stepsPerBeat;
    if (_running) {
      final now = _clock.elapsedMicroseconds / 1000.0;
      _loopStartMs = now - _next * newStepMs;
    }
    _stepMs = newStepMs;
    if (_next >= _steps) _next = 0;
  }

  void start() {
    if (_running) return;
    _running = true;
    _next = 0;
    _loopStartMs = 0;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(
      const Duration(milliseconds: _pollMs),
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

  void _dispatch() {
    if (!_running) return;
    final now = _clock.elapsedMicroseconds / 1000.0;
    var guard = 0;
    while (_running && guard < _maxStepsPerPoll) {
      guard++;
      if (_next >= _steps) {
        _loopStartMs += _steps * _stepMs;
        _next = 0;
      }
      final due = _dueFor(_next);
      if (due <= now) {
        onStep(_next);
        _next++;
      } else {
        break;
      }
    }
  }
}
