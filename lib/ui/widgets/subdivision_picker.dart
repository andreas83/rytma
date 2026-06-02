import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subdivision.dart';
import '../../state/metronome_controller.dart';

/// Choice chips for selecting how each beat is subdivided.
class SubdivisionPicker extends StatelessWidget {
  const SubdivisionPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final current = controller.state.subdivision;

    return Wrap(
      spacing: 8,
      children: [
        for (final s in Subdivision.values)
          ChoiceChip(
            label: Text(s.label),
            selected: s == current,
            onSelected: (_) => controller.setSubdivision(s),
          ),
      ],
    );
  }
}
