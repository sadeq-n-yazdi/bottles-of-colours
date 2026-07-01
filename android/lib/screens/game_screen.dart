import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';
import '../game/level.dart';
import '../profile/profile_store.dart';
import '../widgets/bottle_widget.dart';

/// Game screen. Accepts either a numbered [level] or a fully-custom puzzle
/// spec (totalBottles / slotCount / emptyBottles). Levels use deterministic
/// seeds; custom puzzles get a fresh random seed each time.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.level,
    this.totalBottles,
    this.slotCount,
    this.emptyBottles,
    this.title,
  }) : assert(level != null || totalBottles != null,
            'Provide a level or totalBottles.');

  final Level? level;
  final int? totalBottles;
  final int? slotCount;
  final int? emptyBottles;
  final String? title;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _state;
  late final int _slotCount;
  bool _winShown = false;
  bool _stuckShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.level != null) {
      final lvl = widget.level!;
      _slotCount = lvl.slotCount;
      _state = GameState(
        totalBottles: lvl.totalBottles,
        slotCount: lvl.slotCount,
        seed: lvl.seed,
      );
    } else {
      _slotCount = widget.slotCount ?? 5;
      _state = GameState(
        totalBottles: widget.totalBottles!,
        slotCount: _slotCount,
        emptyBottles: widget.emptyBottles ?? 2,
      );
    }
    _state.addListener(_onChange);
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    _state.dispose();
    super.dispose();
  }

  void _onChange() {
    setState(() {});
    if (_state.isWon && !_winShown) {
      _winShown = true;
      HapticFeedback.heavyImpact();
      // Persist progress before showing the dialog so a quick back-tap still
      // records the win.
      if (widget.level != null) {
        ProfileScope.of(context).recordWin(widget.level!.number);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    } else if (_state.isStuck && !_stuckShown && !_winShown) {
      _stuckShown = true;
      HapticFeedback.mediumImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showStuckDialog());
    }
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    final err = _state.tapBottle(index);
    if (err != null) {
      // Reject pour or empty source: distinct buzz so it's felt as "no".
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(err),
          duration: const Duration(milliseconds: 900),
        ));
    }
  }

  void _hint() {
    final err = _state.useHint();
    if (err != null) {
      // No hint given (won / stuck / none left): same "no" feedback as a
      // rejected pour.
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(err),
          duration: const Duration(milliseconds: 900),
        ));
    } else {
      HapticFeedback.selectionClick();
    }
  }

  String get _title {
    if (widget.title != null) return widget.title!;
    if (widget.level != null) return 'Level ${widget.level!.number}';
    return 'Puzzle';
  }

  void _showWinDialog() {
    final lvl = widget.level;
    final hasNext = lvl != null && lvl.number < Level.totalLevels;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('You Win!'),
        content: Text(
          hasNext
              ? '$_title solved in ${_state.moves} moves.\n'
                  'Ready for level ${lvl.number + 1}?'
              : '$_title solved in ${_state.moves} moves.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _winShown = false;
              _stuckShown = false;
              widget.level != null ? _state.reset() : _state.newLevel();
            },
            child: const Text('Replay'),
          ),
          if (hasNext)
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: Text('Level ${lvl.number + 1}'),
              onPressed: () {
                Navigator.of(ctx).pop();
                // Replace this screen so back navigates to Home, not the
                // just-solved level.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GameScreen(level: Level(lvl.number + 1)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showStuckDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('No more moves'),
        content: const Text(
          'There are no valid pours left. Undo to back up, or reset the '
          'puzzle to try again.',
        ),
        actions: <Widget>[
          if (_state.canUndo)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _stuckShown = false;
                _state.undo();
              },
              child: const Text('Undo'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _stuckShown = false;
              _state.reset();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: <Widget>[
          _HintButton(
            available: _state.availableHints,
            enabled: _state.canHint,
            onPressed: _hint,
          ),
          _UndoButton(
            available: _state.availableUndos,
            enabled: _state.canUndo,
            onPressed: () {
              HapticFeedback.lightImpact();
              _state.undo();
              _stuckShown = false;
            },
          ),
          IconButton(
            tooltip: 'Reset level',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              _winShown = false;
              _stuckShown = false;
              _state.reset();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (ctx, constraints) {
            final layout = _LayoutSolver.solve(
              count: _state.bottles.length,
              available: Size(constraints.maxWidth, constraints.maxHeight),
              natural: BottleWidget.naturalSize(_slotCount),
              spacing: 4,
            );
            return Center(
              child: SizedBox(
                width: layout.totalSize.width,
                height: layout.totalSize.height,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: layout.spacing,
                  runSpacing: layout.spacing,
                  children: <Widget>[
                    for (int i = 0; i < _state.bottles.length; i++)
                      SizedBox(
                        width: layout.cellSize.width,
                        height: layout.cellSize.height,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: BottleWidget(
                            bottle: _state.bottles[i],
                            selected: _state.selectedIndex == i ||
                                _state.hintDst == i,
                            pouring: _state.lastPourSrc == i ||
                                _state.hintSrc == i,
                            onTap: () => _handleTap(i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Moves: ${_state.moves}     '
            'Undos: ${_state.availableUndos}/$kMaxUndosHeld     '
            'Hints: ${_state.availableHints}/$kMaxHintsHeld',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

/// Computes the best (rows, cols) split that maximizes the scale at which
/// the bottles can be drawn while still fitting inside [available].
class _LayoutSolver {
  const _LayoutSolver({
    required this.cellSize,
    required this.totalSize,
    required this.spacing,
  });

  final Size cellSize;
  final Size totalSize;
  final double spacing;

  static _LayoutSolver solve({
    required int count,
    required Size available,
    required Size natural,
    required double spacing,
  }) {
    double bestScale = 0;
    int bestCols = 1;
    int bestRows = count;
    for (int cols = 1; cols <= count; cols++) {
      final rows = (count / cols).ceil();
      final cellW = (available.width - (cols - 1) * spacing) / cols;
      final cellH = (available.height - (rows - 1) * spacing) / rows;
      if (cellW <= 0 || cellH <= 0) continue;
      final scale = min(cellW / natural.width, cellH / natural.height);
      if (scale > bestScale) {
        bestScale = scale;
        bestCols = cols;
        bestRows = rows;
      }
    }
    // Cap upscaling so very few bottles don't render gigantic.
    final scale = bestScale > 1.4 ? 1.4 : bestScale;
    final cellW = natural.width * scale;
    final cellH = natural.height * scale;
    final totalW = cellW * bestCols + spacing * (bestCols - 1);
    final totalH = cellH * bestRows + spacing * (bestRows - 1);
    return _LayoutSolver(
      cellSize: Size(cellW, cellH),
      totalSize: Size(totalW, totalH),
      spacing: spacing,
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({
    required this.available,
    required this.enabled,
    required this.onPressed,
  });

  final int available;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _BadgeIconButton(
      icon: Icons.undo,
      badge: '$available',
      badgeColor: Colors.amber,
      enabled: enabled,
      tooltip: 'Undo (1 earned per $kMovesPerUndo moves, '
          'max $kMaxUndosHeld held)',
      onPressed: onPressed,
    );
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.available,
    required this.enabled,
    required this.onPressed,
  });

  final int available;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _BadgeIconButton(
      icon: Icons.lightbulb_outline,
      badge: '$available',
      badgeColor: Colors.lightBlueAccent,
      enabled: enabled,
      tooltip: 'Hint (start with $kFreeHints, +1 per $kMovesPerHint moves, '
          'max $kMaxHintsHeld held)',
      onPressed: onPressed,
    );
  }
}

/// An [IconButton] with a small count badge in the top-right corner. Shared by
/// the undo and hint buttons so their look stays in sync.
class _BadgeIconButton extends StatelessWidget {
  const _BadgeIconButton({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String badge;
  final Color badgeColor;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(icon),
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: enabled ? badgeColor : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
