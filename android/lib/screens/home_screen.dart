import 'package:flutter/material.dart';

import '../game/level.dart';
import '../profile/profile_store.dart';
import 'custom_puzzle_screen.dart';
import 'game_screen.dart';
import 'levels_screen.dart';
import 'player_picker_screen.dart';

/// Landing screen: shows the active player, a big Play button (resumes at
/// their next unsolved level), and secondary buttons for Levels / Custom /
/// Change player. Auto-prompts for a player on first launch.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _pickerPrompted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = ProfileScope.of(context);
    if (store.active == null && !_pickerPrompted) {
      _pickerPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPicker(true));
    }
  }

  Future<void> _openPicker(bool forced) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPickerScreen(forced: forced),
      ),
    );
  }

  void _playNext(BuildContext context) {
    final player = ProfileScope.of(context).active!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: Level(player.nextLevel)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ProfileScope.of(context);
    final player = store.active;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 24),
              const Text(
                'Bottle of Colors',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sort the liquids!',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const Spacer(),
              if (player != null) ...<Widget>[
                _PlayerBadge(name: player.name),
                const SizedBox(height: 12),
                Text(
                  player.hasFinishedAll
                      ? 'You solved every level. Replay or start a custom one!'
                      : player.lastSolvedLevel == 0
                          ? "You're about to start level 1"
                          : 'Up next: level ${player.nextLevel}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 36),
                    label: Text(
                      'Play  ·  Level ${player.nextLevel}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _playNext(context),
                  ),
                ),
              ] else ...<Widget>[
                FilledButton.icon(
                  onPressed: () => _openPicker(false),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create a player to start'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Levels'),
                      onPressed: player == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LevelsScreen(),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('Custom'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CustomPuzzleScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _openPicker(false),
                icon: const Icon(Icons.switch_account),
                label: const Text('Change player'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.person, size: 18),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
