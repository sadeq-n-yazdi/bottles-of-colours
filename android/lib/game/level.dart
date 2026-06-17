import 'game_state.dart';

/// Static metadata about a numbered puzzle level.
///
/// Bottle count grows every 5 levels (4 bottles at level 1, up to 14 by
/// level 51+). Slot count climbs more slowly so early levels stay friendly.
class Level {
  const Level(this.number);

  final int number;

  static const int totalLevels = 100;

  int get totalBottles {
    final n = 4 + (number - 1) ~/ 5;
    // Two empty bottles + palette caps the total.
    final cap = kMaxColors + 2;
    return n > cap ? cap : n;
  }

  /// Slot count starts at 4, bumps to 5 at level 11, 6 at level 41,
  /// 7 at level 71. Provides a slow ramp of complexity beyond bottle count.
  int get slotCount {
    if (number < 11) return 4;
    if (number < 41) return 5;
    if (number < 71) return 6;
    return 7;
  }

  int get numColors => totalBottles - 2;

  /// Deterministic seed so each level always produces the same starting layout.
  int get seed => number * 1009 + 17;
}
