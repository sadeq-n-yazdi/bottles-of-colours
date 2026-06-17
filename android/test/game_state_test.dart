import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_sort_puzzle/game/bottle.dart';
import 'package:water_sort_puzzle/game/game_state.dart';

void main() {
  group('Bottle', () {
    test('topRunLength counts contiguous top color', () {
      final b = Bottle(const [Colors.red, Colors.blue, Colors.blue]);
      expect(b.topColor, Colors.blue);
      expect(b.topRunLength, 2);
    });

    test('isSolved when full single color or empty', () {
      expect(Bottle.empty().isSolved, true);
      expect(
        Bottle(List<Color>.filled(5, Colors.red), capacity: 5).isSolved,
        true,
      );
      expect(Bottle(const [Colors.red, Colors.blue]).isSolved, false);
    });

    test('honors per-bottle capacity', () {
      final b = Bottle(const [Colors.red, Colors.red], capacity: 3);
      expect(b.isFull, false);
      expect(b.freeSpace, 1);
      b.units.add(Colors.red);
      expect(b.isFull, true);
      expect(b.isSolved, true);
    });
  });

  group('GameState', () {
    test('11 bottles / 9 colors generates correctly', () {
      final g = GameState(totalBottles: 11, seed: 1);
      expect(g.bottles.length, 11);
      expect(g.bottles.where((b) => b.isEmpty).length, 2);
      expect(g.bottles.where((b) => b.isFull).length, 9);
    });

    test('honors custom slot count', () {
      final g = GameState(totalBottles: 6, slotCount: 3, seed: 1);
      expect(g.bottles.length, 6);
      expect(g.bottles.first.capacity, 3);
      expect(g.bottles.first.units.length, 3);
    });

    test('honors custom emptyBottles', () {
      final g = GameState(totalBottles: 5, emptyBottles: 1, seed: 1);
      expect(g.bottles.where((b) => b.isEmpty).length, 1);
      expect(g.bottles.where((b) => b.isFull).length, 4);
    });

    test('pours all contiguous same-color top units at once', () {
      final g = GameState(totalBottles: 5, seed: 1);
      g.bottles[0] = Bottle(const [Colors.red, Colors.red, Colors.red],
          capacity: 5);
      g.bottles[1] = Bottle(const [Colors.red], capacity: 5);
      g.tapBottle(0);
      final err = g.tapBottle(1);
      expect(err, null);
      expect(g.bottles[0].units, isEmpty);
      expect(g.bottles[1].units.length, 4);
    });

    test('rejects pour on color mismatch', () {
      final g = GameState(totalBottles: 5, seed: 1);
      g.bottles[0] = Bottle(const [Colors.red], capacity: 5);
      g.bottles[1] = Bottle(const [Colors.blue], capacity: 5);
      g.tapBottle(0);
      final err = g.tapBottle(1);
      expect(err, isNotNull);
    });

    test('isWon when every bottle empty or full single color', () {
      final g = GameState(totalBottles: 5, seed: 1);
      g.bottles = [
        Bottle(List<Color>.filled(5, Colors.red), capacity: 5),
        Bottle(List<Color>.filled(5, Colors.blue), capacity: 5),
        Bottle(List<Color>.filled(5, Colors.green), capacity: 5),
        Bottle.empty(capacity: 5),
        Bottle.empty(capacity: 5),
      ];
      expect(g.isWon, true);
    });

    test('detects stuck state with no valid pours', () {
      final g = GameState(totalBottles: 3, emptyBottles: 1, seed: 1);
      // Force a dead-end: two full bottles of different colors, one full of
      // a third color, all different tops, no empty space anywhere.
      g.bottles = [
        Bottle(List<Color>.filled(5, Colors.red), capacity: 5),
        Bottle(List<Color>.filled(5, Colors.blue), capacity: 5),
        // last bottle: not solved (mixed colors) but no valid moves
        Bottle(const [Colors.green, Colors.green, Colors.red, Colors.blue,
            Colors.green], capacity: 5),
      ];
      expect(g.isWon, false);
      expect(g.isStuck, true);
    });

    test('undo earns 1 per 10 moves, capped at 3', () {
      final g = GameState(totalBottles: 5, seed: 1);
      expect(g.availableUndos, 0);
      g.bottles[0] = Bottle(const [Colors.red, Colors.red], capacity: 5);
      g.bottles[1] = Bottle.empty(capacity: 5);
      // Force-bump moves to test the formula independent of pour mechanics.
      g.moves = 9;
      expect(g.availableUndos, 0);
      g.moves = 10;
      expect(g.availableUndos, 1);
      g.moves = 35;
      expect(g.availableUndos, 3); // capped
      g.moves = 100;
      expect(g.availableUndos, 3); // still capped
    });

    test('undo restores previous bottle state and consumes one undo', () {
      final g = GameState(totalBottles: 5, seed: 1);
      g.bottles[0] = Bottle(const [Colors.red, Colors.red, Colors.red],
          capacity: 5);
      g.bottles[1] = Bottle.empty(capacity: 5);
      g.tapBottle(0);
      g.tapBottle(1);
      expect(g.bottles[0].units, isEmpty);
      expect(g.bottles[1].units.length, 3);
      // Player has 1 move; grant an undo.
      g.moves = 10;
      expect(g.canUndo, true);
      g.undo();
      expect(g.bottles[0].units.length, 3);
      expect(g.bottles[1].units, isEmpty);
      expect(g.undosUsed, 1);
    });
  });
}
