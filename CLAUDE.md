# CLAUDE.md

Guidance for AI assistants (and humans) working in this repository.

## What this is

**Metro Power** is a cross-platform **Flutter** metronome and rhythm-practice
app. It targets Android, iOS, and Web from a single Dart codebase. Beyond a
basic click, it offers:

- **Metronome** — adjustable tempo (20–400 BPM), tap tempo, time signatures,
  per-beat accents (strong / normal / weak / mute), and subdivisions
  (eighths, triplets, 16ths, quintuplets, sextuplets).
- **Polyrhythm** — a second voice of *N* evenly spaced pulses against the bar,
  giving a `beats : N` cross-rhythm with a color-coded visualizer and a
  selectable timbre + volume for the cross-voice.
- **Training** — a *tempo ramp* ("automator") that changes BPM over time and a
  *gap trainer* ("coach") that periodically mutes the click.
- **Looper** — record microphone takes that loop continuously and stack as
  layers, with per-layer volume / mute / solo, undo, stop-all and clear.
- **Tuner (Stimmgerät)** — chromatic pitch detection (note + cents) from the mic,
  using the YIN algorithm (`engine/pitch.dart`).
- **Spectrogram** — live FFT heatmap of the mic input, optionally overlaying the
  metronome's bar downbeats.
- **Setlist** — built-in starter presets plus save/recall of named user presets.

## Tech stack

- Flutter 3.44 / Dart 3.12 (Material 3, dark theme).
- State management: [`provider`](https://pub.dev/packages/provider)
  (`ChangeNotifier`).
- Audio out: [`flutter_soloud`](https://pub.dev/packages/flutter_soloud) for
  low-latency click playback (loads PCM straight from memory, overlapping
  voices). **Click samples are synthesized at runtime** (see `ClickSynth`) —
  there are no binary audio assets in the repo.
- Recording/looping: [`record`](https://pub.dev/packages/record) (mic capture)
  + [`audioplayers`](https://pub.dev/packages/audioplayers) (looping playback),
  with [`path_provider`](https://pub.dev/packages/path_provider) for temp files.
- Mic analysis (tuner + spectrogram): [`record`](https://pub.dev/packages/record)
  `startStream` for live PCM + [`fftea`](https://pub.dev/packages/fftea) for the
  FFT. Pitch detection is hand-rolled autocorrelation (`engine/pitch.dart`).
- Persistence: [`shared_preferences`](https://pub.dev/packages/shared_preferences)
  (presets + last-used state as JSON).

> Note: the audio backend is isolated behind `AudioClicks` (see Architecture),
> so it can be swapped without touching the engine, controller, or UI. (An
> earlier version used `soundpool`, but it is discontinued and fails to compile
> on modern Android — `flutter_soloud` replaced it.)

## Project layout

```
lib/
  main.dart                  App entry; sets up providers + MaterialApp.
  models/                    Immutable data types (no Flutter imports).
    time_signature.dart
    subdivision.dart         enum: pulses-per-beat.
    accent.dart              enum: mute / weak / normal / strong.
    poly_timbre.dart         enum: selectable polyrhythm-voice sound.
    trainer_config.dart      Tempo-ramp + gap-trainer settings.
    metronome_state.dart     The full serializable app state.
    preset.dart              A named saved MetronomeState.
    factory_presets.dart     Built-in starter presets.
  engine/                    Framework-agnostic timing/DSP core (pure Dart).
    tick_event.dart          ClickType enum + TickEvent.
    click_synth.dart         Generates 16-bit mono WAV click samples in memory.
    metronome_engine.dart    Stopwatch + look-ahead scheduler.
    pitch.dart               Frequency→note math + autocorrelation detector.
  services/                  Platform/plugin wrappers.
    audio_clicks.dart        flutter_soloud wrapper; loads synthesized clicks.
    loop_recorder.dart       record + audioplayers looper (ChangeNotifier).
    audio_analyzer.dart      Mic stream → FFT spectrogram + pitch (ChangeNotifier).
    preset_store.dart        shared_preferences persistence.
  state/
    metronome_controller.dart  The central view-model (ChangeNotifier).
  ui/
    theme.dart               Color palette + ThemeData.
    home_shell.dart          NavigationBar + persistent TransportBar.
    screens/                 metronome / polyrhythm / training / looper /
                             analyzer (tuner + spectrogram) / setlist
    widgets/                 tempo_control / beat_grid / subdivision_picker /
                             transport_bar / tuner_gauge / spectrogram_view
test/
  widget_test.dart           Pure-Dart unit tests (models + ClickSynth).
```

## Architecture (how a click happens)

The design separates **timing**, **audio**, and **UI** so each is testable and
replaceable.

1. **`MetronomeState`** describes *what* to play (tempo, meter, accents,
   subdivision, polyrhythm, trainer config). It is immutable; mutations go
   through `copyWith`.

2. **`MetronomeEngine`** decides *when*. From the current state it pre-computes
   the ordered list of `TickEvent`s for **one bar** (primary voice +
   optional polyrhythm voice). A high-resolution `Stopwatch` is the
   authoritative clock; a short (`4 ms`) periodic `Timer` polls it and fires
   every event whose time has elapsed. The loop-start time is advanced by exact
   bar durations, so **timing does not drift** even though the poll timer is
   coarse. The engine only emits callbacks — it has no Flutter or audio
   dependency, which is why it can be unit-tested.

3. **`MetronomeController`** (the view-model) wires it together: it owns the
   engine, plays the right `ClickType` through **`AudioClicks`** on each
   audible tick, applies trainer logic, exposes simple mutator methods to the
   UI, and persists changes via `PresetStore`. It is the single
   `ChangeNotifier` the screens listen to.

4. **Beat highlighting** is published separately via
   `MetronomeController.pulse` (a `ValueNotifier<TickEvent?>`). Widgets that
   animate per-tick (`BeatGrid`, polyrhythm rows) use a `ValueListenableBuilder`
   on it, so the 4 ms tick stream does **not** rebuild the whole widget tree —
   only `notifyListeners()` (on settings changes) does.

```
MetronomeState ──> MetronomeEngine ──(TickEvent)──> MetronomeController ──> AudioClicks (sound)
                                                          │
                                                          ├─> pulse (ValueNotifier) ──> BeatGrid / visualizers
                                                          └─> notifyListeners() ──> control widgets
```

Two voices: `TickEvent.voice == 0` is the primary metronome, `voice == 1` is the
polyrhythm. The polyrhythm is `polyPulses` clicks spread evenly across the whole
bar, producing a `timeSignature.beats : polyPulses` ratio.

The **looper** (`LoopRecorder`) is an independent `ChangeNotifier` provider; it
runs alongside the metronome and is unrelated to the engine.

The **analyzer** (`AudioAnalyzer`, also an independent provider) streams live
PCM from the mic (`record.startStream`), runs an FFT (`fftea`) for the
spectrogram and autocorrelation (`engine/pitch.dart`) for the tuner, and keeps a
rolling history of spectral columns. The Analyzer screen listens to
`MetronomeController.pulse` and calls `AudioAnalyzer.markBar()` on each downbeat
so the spectrogram can draw bar lines. Note: only one mic consumer should run at
a time (looper vs. analyzer).

## Conventions

- **Layering is one-directional:** `ui → state → engine/services → models`.
  `models/` and `engine/` must **not** import Flutter. Keep platform/plugin code
  inside `services/`.
- New persistent setting? Add the field to `MetronomeState` *with a default*,
  update `copyWith` **and** `toJson`/`fromJson` (read tolerantly — old presets
  must still load), then expose a mutator on `MetronomeController`.
- New click sound? Add a value to `ClickType`, synthesize and load it in
  `AudioClicks.init`, and emit it from `MetronomeEngine._rebuild`.
- Mutators on the controller go through `_apply(...)`, which updates the engine
  and persists the last state. Don't mutate `_state` directly.
- Style: Material 3, `flutter_lints` (see `analysis_options.yaml`), single
  quotes, trailing commas, `const` where possible. Keep the analyzer at **zero
  issues**.

## Developer workflow

This repo includes a SessionStart hook that puts Flutter on `PATH` for web
sessions. If running locally, ensure the Flutter SDK is installed.

```bash
flutter pub get          # restore dependencies
flutter analyze          # static analysis — keep this clean
flutter test             # unit tests (pure-Dart; no device needed)
flutter run              # run on a connected device / emulator / browser
flutter build web        # or: build apk / build ios / build appbundle
flutter run -d chrome    # web (mic recording needs https or localhost)
```

**Testing note:** tests cover pure-Dart code (models, `ClickSynth`). The engine
is also pure Dart and unit-testable; the controller, audio, recorder, and
preference store touch platform plugins, so test them with fakes/mocks or in
integration tests rather than plain `flutter test`.

## Platform notes

- Microphone permission is declared in
  `android/app/src/main/AndroidManifest.xml` (`RECORD_AUDIO`) and
  `ios/Runner/Info.plist` (`NSMicrophoneUsageDescription`). Update both if the
  recording flow changes.
- Web microphone capture requires a secure context (https or `localhost`).
