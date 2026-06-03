import 'dart:typed_data';

/// Minimal 16-bit PCM WAV encoder. Used both to synthesize click samples and to
/// wrap recorded loop PCM so it can be loaded into the audio engine from memory.
class Wav {
  const Wav._();

  static Uint8List encode(
    Int16List samples, {
    int sampleRate = 44100,
    int channels = 1,
  }) {
    final dataLength = samples.length * 2;
    final header = ByteData(44);

    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    final byteRate = sampleRate * channels * 2;
    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM subchunk size
    header.setUint16(20, 1, Endian.little); // audio format = PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    writeAscii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);

    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(samples.buffer.asUint8List(samples.offsetInBytes, dataLength));
    return out.toBytes();
  }
}
