/// Real-time effect settings for the sequencer's synth bus. Normalized 0..1
/// params (the audio service maps them to filter units); immutable + tolerant
/// JSON like the rest of the models.
class FxSettings {
  final bool reverbOn;
  final double reverbWet;
  final double reverbRoom;

  final bool echoOn;
  final double echoWet;
  final double echoDelay; // seconds-ish (mapped in the service)
  final double echoDecay;

  final bool lpfOn;
  final double lpfCutoff; // 0 = dark, 1 = open
  final double lpfResonance;

  final bool compOn;

  const FxSettings({
    this.reverbOn = false,
    this.reverbWet = 0.3,
    this.reverbRoom = 0.7,
    this.echoOn = false,
    this.echoWet = 0.3,
    this.echoDelay = 0.3,
    this.echoDecay = 0.5,
    this.lpfOn = false,
    this.lpfCutoff = 1.0,
    this.lpfResonance = 0.2,
    this.compOn = false,
  });

  FxSettings copyWith({
    bool? reverbOn,
    double? reverbWet,
    double? reverbRoom,
    bool? echoOn,
    double? echoWet,
    double? echoDelay,
    double? echoDecay,
    bool? lpfOn,
    double? lpfCutoff,
    double? lpfResonance,
    bool? compOn,
  }) =>
      FxSettings(
        reverbOn: reverbOn ?? this.reverbOn,
        reverbWet: reverbWet ?? this.reverbWet,
        reverbRoom: reverbRoom ?? this.reverbRoom,
        echoOn: echoOn ?? this.echoOn,
        echoWet: echoWet ?? this.echoWet,
        echoDelay: echoDelay ?? this.echoDelay,
        echoDecay: echoDecay ?? this.echoDecay,
        lpfOn: lpfOn ?? this.lpfOn,
        lpfCutoff: lpfCutoff ?? this.lpfCutoff,
        lpfResonance: lpfResonance ?? this.lpfResonance,
        compOn: compOn ?? this.compOn,
      );

  Map<String, dynamic> toJson() => {
        'reverbOn': reverbOn,
        'reverbWet': reverbWet,
        'reverbRoom': reverbRoom,
        'echoOn': echoOn,
        'echoWet': echoWet,
        'echoDelay': echoDelay,
        'echoDecay': echoDecay,
        'lpfOn': lpfOn,
        'lpfCutoff': lpfCutoff,
        'lpfResonance': lpfResonance,
        'compOn': compOn,
      };

  factory FxSettings.fromJson(Map<String, dynamic> json) {
    double d(String k, double fallback) =>
        (json[k] as num?)?.toDouble().clamp(0.0, 1.0) ?? fallback;
    return FxSettings(
      reverbOn: json['reverbOn'] == true,
      reverbWet: d('reverbWet', 0.3),
      reverbRoom: d('reverbRoom', 0.7),
      echoOn: json['echoOn'] == true,
      echoWet: d('echoWet', 0.3),
      echoDelay: d('echoDelay', 0.3),
      echoDecay: d('echoDecay', 0.5),
      lpfOn: json['lpfOn'] == true,
      lpfCutoff: d('lpfCutoff', 1.0),
      lpfResonance: d('lpfResonance', 0.2),
      compOn: json['compOn'] == true,
    );
  }
}
