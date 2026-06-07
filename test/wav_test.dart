import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rytma/engine/wav.dart';

void main() {
  test('Wav.encode writes a correct 16-bit PCM header and data', () {
    final samples = Int16List.fromList([0, 1000, -1000, 32767, -32768]);
    final bytes = Wav.encode(samples, sampleRate: 22050);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    final header = ByteData.sublistView(bytes, 0, 44);
    expect(header.getUint16(22, Endian.little), 1); // channels
    expect(header.getUint32(24, Endian.little), 22050); // sample rate
    expect(header.getUint16(34, Endian.little), 16); // bits per sample
    expect(header.getUint32(40, Endian.little), samples.length * 2); // data size
    expect(bytes.length, 44 + samples.length * 2);

    // First sample round-trips.
    expect(header.lengthInBytes, 44);
    final data = ByteData.sublistView(bytes, 44);
    expect(data.getInt16(2, Endian.little), 1000);
  });

  test('Wav.encode respects a sliced (offset) sample view', () {
    final full = Int16List.fromList([5, 6, 7, 8, 9, 10]);
    final view = Int16List.sublistView(full, 2, 5); // [7, 8, 9]
    final bytes = Wav.encode(view, sampleRate: 44100);

    final header = ByteData.sublistView(bytes, 0, 44);
    expect(header.getUint32(40, Endian.little), 3 * 2);
    final data = ByteData.sublistView(bytes, 44);
    expect(data.getInt16(0, Endian.little), 7);
    expect(data.getInt16(4, Endian.little), 9);
  });
}
