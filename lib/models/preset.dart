import 'metronome_state.dart';

/// A named, saved [MetronomeState] for setlists / quick recall.
class Preset {
  final String id;
  final String name;
  final MetronomeState state;

  const Preset({required this.id, required this.name, required this.state});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'state': state.toJson()};

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        id: json['id'] as String,
        name: json['name'] as String,
        state: MetronomeState.fromJson(json['state'] as Map<String, dynamic>),
      );
}
