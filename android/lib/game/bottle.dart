import 'package:flutter/material.dart';

/// A test tube that can hold up to [capacity] colored units, stacked
/// bottom-to-top. The unit at index 0 is at the bottom; the unit at
/// `units.last` is the top (what would pour out first).
class Bottle {
  Bottle(List<Color> initial, {this.capacity = 5})
      : units = List<Color>.from(initial) {
    assert(units.length <= capacity);
  }

  Bottle.empty({this.capacity = 5}) : units = <Color>[];

  /// Default slot count used when none is specified.
  static const int defaultCapacity = 5;

  final int capacity;
  final List<Color> units;

  Bottle copy() => Bottle(units, capacity: capacity);

  bool get isEmpty => units.isEmpty;
  bool get isFull => units.length >= capacity;
  int get freeSpace => capacity - units.length;

  Color? get topColor => units.isEmpty ? null : units.last;

  /// Number of contiguous same-color units starting from the top.
  int get topRunLength {
    if (units.isEmpty) return 0;
    final top = units.last;
    int n = 0;
    for (int i = units.length - 1; i >= 0; i--) {
      if (units[i] == top) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// Solved means empty, or completely full with one single color.
  bool get isSolved {
    if (isEmpty) return true;
    if (units.length != capacity) return false;
    final c = units.first;
    return units.every((u) => u == c);
  }
}
