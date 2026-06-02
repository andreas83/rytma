import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:fftea/fftea.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../engine/pitch.dart';

/// Streams microphone audio and derives two things in real time:
///
/// * a detected pitch ([reading]) for the tuner, and
/// * a rolling log-scaled magnitude [spectrogram] for the spectrogram view.
///
/// Incoming PCM16 frames are accumulated into a sliding analysis window; once a
/// full window is available it is Hann-windowed and run through an FFT (for the
/// spectrum) and an autocorrelation pitch detector (for the tuner).
class AudioAnalyzer extends ChangeNotifier {
  static const int sampleRate = 44100;
  static const int fftSize = 2048;
  static const int displayBins = 110;
  static const int maxColumns = 240;

  final AudioRecorder _recorder = AudioRecorder();
  final FFT _fft = FFT(fftSize);
  final Float64List _window = _hann(fftSize);

  StreamSubscription<Uint8List>? _sub;
  final Float64List _frame = Float64List(fftSize);
  int _filled = 0;

  bool _running = false;
  String? _error;
  NoteReading? _reading;

  /// Rolling history of spectral columns (each [displayBins] long, 0..1).
  final ListQueue<Float64List> _spectrogram = ListQueue();

  /// Parallel to [_spectrogram]; true where a metronome downbeat landed.
  final ListQueue<bool> _markers = ListQueue();
  bool _pendingMarker = false;

  bool get isRunning => _running;
  String? get error => _error;
  NoteReading? get reading => _reading;
  List<Float64List> get spectrogram => _spectrogram.toList(growable: false);
  List<bool> get markers => _markers.toList(growable: false);

  /// Flag that a metronome bar started; the next produced column is marked.
  void markBar() => _pendingMarker = true;

  Future<bool> start() async {
    if (_running) return true;
    if (!await _recorder.hasPermission()) {
      _error = 'Microphone permission denied';
      notifyListeners();
      return false;
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    _filled = 0;
    _running = true;
    _error = null;
    _sub = stream.listen(_onData, onError: (Object e) {
      _error = '$e';
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    notifyListeners();
  }

  void clear() {
    _spectrogram.clear();
    _markers.clear();
    _reading = null;
    notifyListeners();
  }

  void _onData(Uint8List bytes) {
    // Interpret as little-endian signed 16-bit PCM, normalized to [-1, 1].
    final samples = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    for (final s in samples) {
      _frame[_filled++] = s / 32768.0;
      if (_filled == fftSize) {
        _analyze();
        // 50% overlap: keep the second half as the start of the next window.
        const half = fftSize ~/ 2;
        _frame.setRange(0, half, _frame, half);
        _filled = half;
      }
    }
  }

  void _analyze() {
    // Pitch on the raw (centered) window.
    _reading = _readingFromFrame();

    // Spectrum on a Hann-windowed copy.
    final windowed = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      windowed[i] = _frame[i] * _window[i];
    }
    final mags = _fft.realFft(windowed).discardConjugates().magnitudes();
    _spectrogram.addLast(_toColumn(mags));
    _markers.addLast(_pendingMarker);
    _pendingMarker = false;
    while (_spectrogram.length > maxColumns) {
      _spectrogram.removeFirst();
      _markers.removeFirst();
    }
    notifyListeners();
  }

  NoteReading? _readingFromFrame() {
    final copy = Float64List.fromList(_frame);
    final hz = Pitch.detectFrequency(copy, sampleRate);
    if (hz == null) return null;
    return Pitch.noteFromFrequency(hz);
  }

  /// Collapse the linear FFT bins into [displayBins] log-spaced, log-scaled
  /// columns in 0..1 for display.
  Float64List _toColumn(Float64List mags) {
    final out = Float64List(displayBins);
    final nyquist = sampleRate / 2;
    const minF = 50.0;
    final maxF = min(nyquist, 10000.0);
    final binHz = nyquist / mags.length;
    for (var i = 0; i < displayBins; i++) {
      final f0 = minF * pow(maxF / minF, i / displayBins);
      final f1 = minF * pow(maxF / minF, (i + 1) / displayBins);
      var lo = (f0 / binHz).floor();
      var hi = (f1 / binHz).ceil();
      lo = lo.clamp(0, mags.length - 1);
      hi = hi.clamp(lo + 1, mags.length);
      var peak = 0.0;
      for (var b = lo; b < hi; b++) {
        if (mags[b] > peak) peak = mags[b];
      }
      // Log compression to a perceptual 0..1 range.
      final db = 20 * (log(peak + 1e-9) / ln10);
      out[i] = ((db + 70) / 70).clamp(0.0, 1.0);
    }
    return out;
  }

  static Float64List _hann(int n) {
    final w = Float64List(n);
    for (var i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
    }
    return w;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
