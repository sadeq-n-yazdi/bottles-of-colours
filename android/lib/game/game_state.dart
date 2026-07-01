import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'bottle.dart';

/// Liquid colors picked for maximum hue + brightness separation on a dark
/// background. Ten colors is the upper bound — beyond that, additional
/// shades tend to be confusable.
const List<Color> kPalette = <Color>[
  Color(0xFFE53935), // 1. red
  Color(0xFFFF8F00), // 2. deep orange
  Color(0xFFFFEB3B), // 3. bright yellow
  Color(0xFF76FF03), // 4. lime green
  Color(0xFF00C853), // 5. forest green
  Color(0xFF00BCD4), // 6. cyan
  Color(0xFF2962FF), // 7. royal blue
  Color(0xFFAA00FF), // 8. vivid purple
  Color(0xFFEC407A), // 9. pink / magenta
  Color(0xFF8D6E63), // 10. brown
];

/// Maximum number of distinct colors the engine can use.
int get kMaxColors => kPalette.length;

/// Earned 1 undo per this many moves.
const int kMovesPerUndo = 3;

/// Cap on how many undos can be held at once.
const int kMaxUndosHeld = 3;

/// Hints available before the first move is made.
const int kFreeHints = 1;

/// Earned 1 additional hint per this many moves.
const int kMovesPerHint = 5;

/// Cap on how many hints can be held at once (mirrors [kMaxUndosHeld]).
const int kMaxHintsHeld = 3;

/// Upper bound on distinct positions the solvability search will explore
/// before giving up. Puzzles at these sizes settle well under this; the cap
/// only guards against a pathological blow-up, and on hitting it we assume
/// "solvable" so we never falsely tell the player they are stuck.
const int kMaxSolverStates = 200000;

/// Hard cap on bottle count: tied to palette size + a couple of empties.
const int kMaxBottles = 12;

/// Hard cap on slot count so the bottle still fits vertically on a phone.
const int kMaxSlots = 8;

/// Holds the mutable puzzle state and the move/win/stuck rules.
class GameState extends ChangeNotifier {
  GameState({
    required this.totalBottles,
    this.slotCount = Bottle.defaultCapacity,
    this.emptyBottles = 2,
    int? seed,
  })  : assert(totalBottles >= 3 && totalBottles <= kMaxBottles),
        assert(slotCount >= 2 && slotCount <= kMaxSlots),
        assert(emptyBottles >= 1 && emptyBottles < totalBottles),
        _seed = seed ?? DateTime.now().millisecondsSinceEpoch {
    assert(
      totalBottles - emptyBottles <= kMaxColors,
      'Need ${totalBottles - emptyBottles} colors but palette only has '
      '$kMaxColors.',
    );
    _generate();
  }

  final int totalBottles;
  final int slotCount;
  final int emptyBottles;
  int _seed;

  late List<Bottle> bottles;
  int? selectedIndex;
  int moves = 0;
  int undosUsed = 0;
  int hintsUsed = 0;

  final List<List<List<Color>>> _history = <List<List<Color>>>[];
  static const int _historyCap = 12;

  int? lastPourSrc;
  int? lastPourDst;
  Timer? _pourTimer;

  // A hint highlights a suggested source/destination pair without pouring.
  // Kept separate from lastPour* because a hint lingers longer and means
  // "you could pour here", not "a pour just happened".
  int? hintSrc;
  int? hintDst;
  Timer? _hintTimer;

  // Memoized solvability of the current board. Cleared on every board
  // mutation (_doPour / undo / _generate). null means "not computed yet" —
  // it is recomputed lazily so repeated widget builds within one position
  // reuse the result instead of re-running the search.
  bool? _solvable;

  bool get isWon => bottles.every((b) => b.isSolved);

  /// True when the puzzle can no longer be won from the current position.
  ///
  /// This is stronger than "no legal pour exists": a board can still offer
  /// legal moves that only shuffle liquid between bottles in a loop without
  /// ever sorting it. Such a dead position used to read as "not stuck" (a
  /// false negative) because a move was technically available. We now decide
  /// it by an exhaustive search over every reachable position — if none of
  /// them is a win, the puzzle is unsolvable and we report it as stuck.
  ///
  /// Reported alongside [isWon] so we never claim "stuck" on a solved board.
  bool get isStuck {
    if (isWon) return false;
    return !(_solvable ??= _searchSolvable());
  }

  /// Depth-first search over reachable positions to decide whether any move
  /// sequence reaches a win. A visited set (keyed on a canonical, order- and
  /// permutation-independent encoding of the bottles) collapses move loops and
  /// symmetric arrangements, so the search terminates. Returns true as soon as
  /// a solved position is reachable; false only after the whole reachable
  /// space is exhausted; and true (conservatively) if [kMaxSolverStates] is
  /// hit first, so we never report a false "stuck".
  bool _searchSolvable() {
    // Map each color present to a small id so positions encode compactly.
    // No pour ever introduces a new color, so ids built from the start
    // position cover every reachable position.
    final colorId = <Color, int>{};
    for (final b in bottles) {
      for (final c in b.units) {
        colorId.putIfAbsent(c, () => colorId.length);
      }
    }

    String canonical(List<Bottle> state) {
      final parts = <String>[
        for (final b in state)
          String.fromCharCodes(<int>[for (final c in b.units) colorId[c]!]),
      ];
      parts.sort();
      return parts.join(',');
    }

    final start = _cloneBottles(bottles);
    final visited = <String>{canonical(start)};
    final stack = <List<Bottle>>[start];
    int budget = kMaxSolverStates;

    while (stack.isNotEmpty) {
      final state = stack.removeLast();
      for (int i = 0; i < state.length; i++) {
        final src = state[i];
        if (src.isEmpty || src.isSolved) continue; // never pour a finished src
        for (int j = 0; j < state.length; j++) {
          if (i == j) continue;
          if (_validatePour(src, state[j]) != null) continue;
          final next = _cloneBottles(state);
          _applyPour(next, i, j);
          if (next.every((b) => b.isSolved)) return true;
          if (visited.add(canonical(next))) {
            if (--budget <= 0) return true; // too large: assume solvable
            stack.add(next);
          }
        }
      }
    }
    return false;
  }

  List<Bottle> _cloneBottles(List<Bottle> state) =>
      <Bottle>[for (final b in state) Bottle(b.units, capacity: b.capacity)];

  void _applyPour(List<Bottle> state, int srcIdx, int dstIdx) {
    final src = state[srcIdx];
    final dst = state[dstIdx];
    final n = min(src.topRunLength, dst.freeSpace);
    final color = src.topColor!;
    for (int i = 0; i < n; i++) {
      src.units.removeLast();
      dst.units.add(color);
    }
  }

  int get availableUndos {
    final earned = moves ~/ kMovesPerUndo;
    final remaining = earned - undosUsed;
    if (remaining <= 0) return 0;
    return remaining > kMaxUndosHeld ? kMaxUndosHeld : remaining;
  }

  bool get canUndo => availableUndos > 0 && _history.isNotEmpty;

  int get availableHints {
    final earned = kFreeHints + moves ~/ kMovesPerHint;
    final remaining = earned - hintsUsed;
    if (remaining <= 0) return 0;
    return remaining > kMaxHintsHeld ? kMaxHintsHeld : remaining;
  }

  bool get canHint => availableHints > 0 && !isWon && !isStuck;

  void _generate() {
    final filled = totalBottles - emptyBottles;
    final pool = <Color>[];
    for (int i = 0; i < filled; i++) {
      for (int j = 0; j < slotCount; j++) {
        pool.add(kPalette[i]);
      }
    }
    pool.shuffle(Random(_seed));

    bottles = <Bottle>[];
    for (int i = 0; i < filled; i++) {
      bottles.add(Bottle(
        pool.sublist(i * slotCount, (i + 1) * slotCount),
        capacity: slotCount,
      ));
    }
    for (int i = 0; i < emptyBottles; i++) {
      bottles.add(Bottle.empty(capacity: slotCount));
    }
    selectedIndex = null;
    moves = 0;
    undosUsed = 0;
    hintsUsed = 0;
    _history.clear();
    lastPourSrc = null;
    lastPourDst = null;
    hintSrc = null;
    hintDst = null;
    _hintTimer?.cancel();
    _solvable = null;
  }

  void reset() {
    _generate();
    notifyListeners();
  }

  void newLevel() {
    _seed = DateTime.now().millisecondsSinceEpoch;
    _generate();
    notifyListeners();
  }

  String? tapBottle(int index) {
    // A fresh interaction supersedes any lingering hint highlight.
    hintSrc = null;
    hintDst = null;
    _hintTimer?.cancel();
    if (selectedIndex == null) {
      if (bottles[index].isEmpty) {
        return 'That bottle is empty — pick a source first.';
      }
      selectedIndex = index;
      notifyListeners();
      return null;
    }
    if (selectedIndex == index) {
      selectedIndex = null;
      notifyListeners();
      return null;
    }
    final src = bottles[selectedIndex!];
    final dst = bottles[index];
    final err = _validatePour(src, dst);
    if (err != null) {
      selectedIndex = null;
      notifyListeners();
      return err;
    }
    _pushHistory();
    _doPour(selectedIndex!, index);
    _flagPour(selectedIndex!, index);
    selectedIndex = null;
    moves++;
    notifyListeners();
    return null;
  }

  void undo() {
    if (!canUndo) return;
    final snap = _history.removeLast();
    for (int i = 0; i < bottles.length; i++) {
      bottles[i] = Bottle(snap[i], capacity: slotCount);
    }
    undosUsed++;
    selectedIndex = null;
    lastPourSrc = null;
    lastPourDst = null;
    _pourTimer?.cancel();
    hintSrc = null;
    hintDst = null;
    _hintTimer?.cancel();
    _solvable = null; // board changed; recompute stuck-ness lazily
    notifyListeners();
  }

  /// Reveals a suggested next move by briefly highlighting a source and
  /// destination bottle. Does NOT perform the pour. Returns null on success,
  /// or a message explaining why no hint was given (won / stuck / none left /
  /// none found). Only consumes a hint once a real move is found.
  String? useHint() {
    if (isWon) return 'Puzzle already solved.';
    if (isStuck) return 'No moves left — try undo or reset.';
    if (availableHints <= 0) return 'No hints available yet.';
    final move = _findHint();
    if (move == null) return 'No helpful move found.';
    hintsUsed++;
    _flagHint(move.$1, move.$2);
    selectedIndex = null; // avoid a confusing double-highlight
    notifyListeners();
    return null;
  }

  /// Picks a constructive pour to suggest. Prefers consolidating a color onto
  /// a matching non-empty bottle, then pouring into an empty bottle, and falls
  /// back to any legal pour. Returns null only when no legal pour exists.
  (int, int)? _findHint() {
    (int, int)? best;
    int bestRank = 0;
    for (int i = 0; i < bottles.length; i++) {
      final src = bottles[i];
      if (src.isEmpty || src.isSolved) continue;
      for (int j = 0; j < bottles.length; j++) {
        if (i == j) continue;
        final dst = bottles[j];
        if (_validatePour(src, dst) != null) continue;
        // Wasteful: relocating a whole mono-color bottle into an empty one.
        final wasteful = dst.isEmpty && src.topRunLength == src.units.length;
        final int rank;
        if (!dst.isEmpty && dst.topColor == src.topColor) {
          rank = 2; // consolidates a color
        } else if (dst.isEmpty && !wasteful) {
          rank = 1; // frees the source top into an empty bottle
        } else {
          rank = wasteful ? 0 : 1;
        }
        if (rank > bestRank || best == null) {
          bestRank = rank;
          best = (i, j);
          // The whole top run fits and consolidates: can't do better.
          if (rank == 2 && dst.freeSpace >= src.topRunLength) return best;
        }
      }
    }
    return best;
  }

  void _flagHint(int srcIdx, int dstIdx) {
    hintSrc = srcIdx;
    hintDst = dstIdx;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      hintSrc = null;
      hintDst = null;
      notifyListeners();
    });
  }

  String? _validatePour(Bottle src, Bottle dst) {
    if (src.isEmpty) return 'Source bottle is empty.';
    if (dst.isFull) return 'Destination bottle is full.';
    if (!dst.isEmpty && dst.topColor != src.topColor) {
      return 'Top colors do not match.';
    }
    return null;
  }

  void _doPour(int srcIdx, int dstIdx) {
    _applyPour(bottles, srcIdx, dstIdx);
    _solvable = null; // board changed; recompute stuck-ness lazily
  }

  void _pushHistory() {
    _history.add([
      for (final b in bottles) List<Color>.from(b.units),
    ]);
    while (_history.length > _historyCap) {
      _history.removeAt(0);
    }
  }

  void _flagPour(int srcIdx, int dstIdx) {
    lastPourSrc = srcIdx;
    lastPourDst = dstIdx;
    _pourTimer?.cancel();
    _pourTimer = Timer(const Duration(milliseconds: 450), () {
      lastPourSrc = null;
      lastPourDst = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pourTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }
}
