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
const int kMovesPerUndo = 10;

/// Cap on how many undos can be held at once.
const int kMaxUndosHeld = 3;

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

  final List<List<List<Color>>> _history = <List<List<Color>>>[];
  static const int _historyCap = 12;

  int? lastPourSrc;
  int? lastPourDst;
  Timer? _pourTimer;

  bool get isWon => bottles.every((b) => b.isSolved);

  /// True when no valid pour exists from any bottle to any other bottle.
  /// Reported alongside [isWon] so we don't claim "stuck" on a solved board.
  bool get isStuck {
    if (isWon) return false;
    for (int i = 0; i < bottles.length; i++) {
      final src = bottles[i];
      if (src.isEmpty) continue;
      for (int j = 0; j < bottles.length; j++) {
        if (i == j) continue;
        if (_validatePour(src, bottles[j]) == null) return false;
      }
    }
    return true;
  }

  int get availableUndos {
    final earned = moves ~/ kMovesPerUndo;
    final remaining = earned - undosUsed;
    if (remaining <= 0) return 0;
    return remaining > kMaxUndosHeld ? kMaxUndosHeld : remaining;
  }

  bool get canUndo => availableUndos > 0 && _history.isNotEmpty;

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
    _history.clear();
    lastPourSrc = null;
    lastPourDst = null;
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
    notifyListeners();
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
    final src = bottles[srcIdx];
    final dst = bottles[dstIdx];
    final n = min(src.topRunLength, dst.freeSpace);
    final color = src.topColor!;
    for (int i = 0; i < n; i++) {
      src.units.removeLast();
      dst.units.add(color);
    }
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
    super.dispose();
  }
}
