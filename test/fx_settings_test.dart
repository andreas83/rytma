import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rytma/models/fx_settings.dart';

void main() {
  group('FxSettings', () {
    test('defaults are all off', () {
      const fx = FxSettings();
      expect(fx.reverbOn, isFalse);
      expect(fx.echoOn, isFalse);
      expect(fx.lpfOn, isFalse);
      expect(fx.compOn, isFalse);
    });

    test('round-trips through JSON', () {
      const fx = FxSettings(
        reverbOn: true,
        reverbWet: 0.6,
        echoOn: true,
        echoDelay: 0.25,
        lpfOn: true,
        lpfCutoff: 0.4,
        lpfResonance: 0.8,
        compOn: true,
      );
      final r = FxSettings.fromJson(jsonDecode(jsonEncode(fx.toJson())));
      expect(r.reverbOn, isTrue);
      expect(r.reverbWet, closeTo(0.6, 1e-9));
      expect(r.echoOn, isTrue);
      expect(r.echoDelay, closeTo(0.25, 1e-9));
      expect(r.lpfOn, isTrue);
      expect(r.lpfCutoff, closeTo(0.4, 1e-9));
      expect(r.lpfResonance, closeTo(0.8, 1e-9));
      expect(r.compOn, isTrue);
    });

    test('tolerates missing keys / out-of-range', () {
      final r = FxSettings.fromJson({'reverbOn': true, 'reverbWet': 9.0});
      expect(r.reverbOn, isTrue);
      expect(r.reverbWet, 1.0); // clamped
      expect(r.echoOn, isFalse); // default
      expect(r.lpfCutoff, 1.0); // default
    });
  });
}
