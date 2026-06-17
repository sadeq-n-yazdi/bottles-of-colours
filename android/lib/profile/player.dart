import '../game/level.dart';

/// A single saved player profile.
class Player {
  Player({required this.name, this.lastSolvedLevel = 0});

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        name: json['name'] as String,
        lastSolvedLevel: (json['lastSolvedLevel'] as int?) ?? 0,
      );

  final String name;
  int lastSolvedLevel;

  /// Level number the player should resume on. Caps at the last level.
  int get nextLevel {
    final n = lastSolvedLevel + 1;
    return n > Level.totalLevels ? Level.totalLevels : n;
  }

  /// True when the player has finished every numbered level.
  bool get hasFinishedAll => lastSolvedLevel >= Level.totalLevels;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'lastSolvedLevel': lastSolvedLevel,
      };
}
