# Metro Power

A cross-platform **Flutter** metronome and rhythm-practice app for Android, iOS,
and Web — built for musicians who need more than a plain click.

## Features

- **Metronome** — 20–400 BPM, tap tempo, time signatures (e.g. 4/4, 6/8, 7/8),
  and per-beat accents you tap to cycle: **strong → normal → weak → mute**.
- **Subdivisions** — eighths, triplets, 16ths, quintuplets, sextuplets, with a
  live beat grid showing exactly where each click lands.
- **Polyrhythm** — layer a second voice of *N* evenly spaced pulses across the
  bar for a `beats : N` cross-rhythm, with a color-coded visualizer plus a
  selectable sound and volume for the cross-voice.
- **Training**
  - *Tempo ramp* — automatically change BPM by a step every few bars up to a
    target (great for speed-building).
  - *Gap trainer* — play a few bars, then mute a few, to test your internal
    clock.
- **Looper** — record short microphone takes that loop and stack as layers, with
  per-layer volume, mute, solo, undo, stop-all, and clear.
- **Tuner (Stimmgerät)** — chromatic instrument tuner with a cents needle and
  frequency readout (A4 = 440 Hz).
- **Spectrogram** — live scrolling FFT view of the incoming audio, with an
  optional overlay marking the metronome's bar downbeats.
- **Setlist** — built-in starter presets plus save/recall of your own named
  presets; your last setup is restored on launch.

The click sounds are **synthesized at runtime**, so the app ships with no audio
asset files and each accent level has its own distinct pitch.

## Getting started

```bash
flutter pub get
flutter run            # device, emulator, or browser
flutter run -d chrome  # web (mic recording requires https or localhost)
```

### Build

```bash
flutter build apk        # Android
flutter build appbundle  # Android (Play Store)
flutter build ios        # iOS (on macOS)
flutter build web        # Web
```

### Quality checks

```bash
flutter analyze   # static analysis (kept clean)
flutter test      # unit tests
```

## Architecture

A quick tour: immutable `MetronomeState` describes *what* to play; a pure-Dart
`MetronomeEngine` (Stopwatch + look-ahead scheduler) decides *when*; a
`MetronomeController` (Provider `ChangeNotifier`) wires ticks to low-latency
audio and the UI. See [`CLAUDE.md`](CLAUDE.md) for the full breakdown, the layer
rules, and how to extend it.

## Permissions

The looper, tuner, and spectrogram need microphone access, declared for Android
(`RECORD_AUDIO`) and iOS (`NSMicrophoneUsageDescription`).
