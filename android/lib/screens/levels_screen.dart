import 'package:flutter/material.dart';

import '../game/level.dart';
import '../profile/profile_store.dart';
import 'game_screen.dart';

/// Grid of every numbered level. Solved levels show a check; the next
/// unsolved level is highlighted so the player can jump back to where
/// they left off.
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = ProfileScope.of(context).active;
    final lastSolved = player?.lastSolvedLevel ?? 0;
    final nextLevel = player?.nextLevel ?? 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Levels')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: Level.totalLevels,
            itemBuilder: (ctx, i) {
              final level = Level(i + 1);
              final solved = level.number <= lastSolved;
              final isNext = level.number == nextLevel;
              return _LevelTile(
                level: level,
                solved: solved,
                isNext: isNext,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.solved,
    required this.isNext,
  });

  final Level level;
  final bool solved;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = solved
        ? scheme.tertiaryContainer
        : isNext
            ? scheme.primary
            : scheme.surfaceContainerHighest;
    final fg = solved
        ? scheme.onTertiaryContainer
        : isNext
            ? scheme.onPrimary
            : scheme.onSurface;

    return FilledButton(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => GameScreen(level: level)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${level.number}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${level.totalBottles}b·${level.slotCount}s',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (solved)
            const Positioned(
              top: 2,
              right: 2,
              child: Icon(Icons.check_circle, size: 16),
            ),
        ],
      ),
    );
  }
}
