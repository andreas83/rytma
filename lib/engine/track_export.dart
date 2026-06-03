import 'dart:typed_data';

import '../models/sequencer_pattern.dart';
import 'synth.dart';
import 'wav.dart';

/// Renders a [SequencerPattern] to a mono 16-bit WAV entirely in Dart (SoLoud
/// can't capture mixed output). Each active step's voice samples are summed into
/// a float accumulator at its swung sample offset — decay tails overlap into
/// following steps, exactly like playback. Per-step velocity scales each hit;
/// probability is ignored (the full pattern is rendered) and FX are not baked in
/// (the export is dry). Pure Dart, so it's unit-testable.
Uint8List renderPattern(
  SequencerPattern p, {
  required double bpm,
  required int loops,
}) {
  final sr = Synth.sampleRate;
  final stepSamples = (sr * 60 / bpm / p.stepsPerBeat).round();
  final total = loops * p.steps * stepSamples;
  final tail = (sr * 0.8).round(); // room for the longest decay tail
  final buf = Float64List(total + tail);

  final drum = <DrumKind, Int16List>{
    DrumKind.kick: Synth.kickSamples(),
    DrumKind.snare: Synth.snareSamples(),
    DrumKind.hat: Synth.hatSamples(),
    DrumKind.clap: Synth.clapSamples(),
  };
  final bassCache = <int, Int16List>{};
  final chordCache = <int, Int16List>{};
  final leadCache = <int, Int16List>{};
  Int16List bassFor(int r) => bassCache.putIfAbsent(
      r, () => Synth.bassSamples(p.root, p.scale, r, wave: p.bassWave));
  Int16List chordFor(int d) => chordCache.putIfAbsent(
      d, () => Synth.chordSamples(p.root, p.scale, d, wave: p.chordWave));
  Int16List leadFor(int r) => leadCache.putIfAbsent(
      r, () => Synth.leadSamples(p.root, p.scale, r, wave: p.leadWave));

  void add(Int16List src, int off, double gain) {
    final lim =
        off + src.length <= buf.length ? src.length : buf.length - off;
    for (var j = 0; j < lim; j++) {
      buf[off + j] += src[j] / 32768.0 * gain;
    }
  }

  for (var l = 0; l < loops; l++) {
    for (var s = 0; s < p.steps; s++) {
      final base = (l * p.steps + s) * stepSamples;
      final off = base + (s.isOdd ? (p.swing * stepSamples).round() : 0);
      for (final k in DrumKind.values) {
        if (p.drumMute[k] != true && p.drums[k]![s]) {
          add(drum[k]!, off, (p.drumVol[k] ?? 0.9) * p.drumVelocity[k]![s].gain);
        }
      }
      if (!p.bassMute) {
        final r = p.bass[s];
        if (r != null) add(bassFor(r), off, p.bassVol * p.bassVelocity[s].gain);
      }
      if (!p.chordMute) {
        final d = p.chords[s];
        if (d != null) {
          add(chordFor(d), off, p.chordVol * p.chordVelocity[s].gain);
        }
      }
      if (!p.leadMute) {
        final r = p.lead[s];
        if (r != null) add(leadFor(r), off, p.leadVol * p.leadVelocity[s].gain);
      }
    }
  }

  final out = Int16List(buf.length);
  for (var i = 0; i < buf.length; i++) {
    out[i] = (buf[i].clamp(-1.0, 1.0) * 32767).toInt();
  }
  return Wav.encode(out, sampleRate: sr);
}
