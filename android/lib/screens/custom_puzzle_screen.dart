import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'game_screen.dart';

/// Form that lets the player dial bottle count, slot count, and empty
/// bottles before generating a random puzzle.
class CustomPuzzleScreen extends StatefulWidget {
  const CustomPuzzleScreen({super.key});

  @override
  State<CustomPuzzleScreen> createState() => _CustomPuzzleScreenState();
}

class _CustomPuzzleScreenState extends State<CustomPuzzleScreen> {
  int _bottles = 6;
  int _slots = 5;
  int _empty = 2;

  int get _colors => _bottles - _empty;
  bool get _isValid =>
      _colors >= 1 && _colors <= kMaxColors && _empty < _bottles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom puzzle')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Stepper(
                label: 'Bottles',
                value: _bottles,
                min: 3,
                max: kMaxBottles,
                onChanged: (v) {
                  setState(() {
                    _bottles = v;
                    if (_empty >= _bottles) _empty = _bottles - 1;
                    if (_colors > kMaxColors) _empty = _bottles - kMaxColors;
                  });
                },
              ),
              _Stepper(
                label: 'Slots per bottle',
                value: _slots,
                min: 2,
                max: kMaxSlots,
                onChanged: (v) => setState(() => _slots = v),
              ),
              _Stepper(
                label: 'Empty bottles',
                value: _empty,
                min: 1,
                max: _bottles - 1,
                onChanged: (v) => setState(() => _empty = v),
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                bottles: _bottles,
                slots: _slots,
                empty: _empty,
                colors: _colors,
                colorsOk: _colors <= kMaxColors,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate puzzle'),
                onPressed: _isValid
                    ? () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => GameScreen(
                              totalBottles: _bottles,
                              slotCount: _slots,
                              emptyBottles: _empty,
                              title: 'Custom puzzle',
                            ),
                          ),
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.bottles,
    required this.slots,
    required this.empty,
    required this.colors,
    required this.colorsOk,
  });

  final int bottles;
  final int slots;
  final int empty;
  final int colors;
  final bool colorsOk;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Colors: $colors (max $kMaxColors)',
                style: TextStyle(
                  color: colorsOk
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text(
              '$bottles bottles · $slots slots · $empty empty',
              style: const TextStyle(color: Colors.white70),
            ),
            if (!colorsOk) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Need $colors colors but only $kMaxColors are defined. '
                'Increase empty bottles or reduce total bottles.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
