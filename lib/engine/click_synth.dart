import 'dart:math';
import 'dart:typed_data';

/// Generates short percussive click samples as in-memory 16-bit mono WAV data.
///
/// Synthesizing the clicks at runtime keeps the repo free of binary audio
/// assets and lets every accent level have a distinct pitch/timbre. Each click
/// is a sine (or square) burst shaped by a fast exponential decay envelope.
class ClickSynth {
  static const int sampleRate = 44100;

  static Uint8List click({
    required double frequency,
    double durationMs = 55,
    double volume = 0.9,
    bool square = false,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(sampleCount);
    // Time constant of the decay; smaller -> snappier click.
    final decay = durationMs * 0.45;
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final env = exp(-t * 1000 / decay);
      var wave = sin(2 * pi * frequency * t);
      if (square) wave = wave >= 0 ? 1.0 : -1.0;
      final value = (wave * env * volume * 32767).clamp(-32768.0, 32767.0);
      samples[i] = value.toInt();
    }
    return _wrapWav(samples);
  }

  static Uint8List _wrapWav(Int16List samples) {
    final dataLength = samples.length * 2;
    final header = ByteData(44);

    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM subchunk size
    header.setUint16(20, 1, Endian.little); // audio format = PCM
    header.setUint16(22, 1, Endian.little); // channels = mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    writeAscii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);

    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(samples.buffer.asUint8List());
    return out.toBytes();
  }
}
