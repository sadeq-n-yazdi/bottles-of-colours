import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player.dart';

/// Persists player profiles and the currently-selected one.
/// Wraps SharedPreferences; exposes a [ChangeNotifier] interface so the UI
/// can rebuild when the active player or their progress changes.
class ProfileStore extends ChangeNotifier {
  ProfileStore._(this._prefs, this._players, this._active);

  static const String _kPlayersJson = 'bof_players_json';
  static const String _kActivePlayer = 'bof_active_player';

  final SharedPreferences _prefs;
  final List<Player> _players;
  Player? _active;

  List<Player> get players => List<Player>.unmodifiable(_players);
  Player? get active => _active;

  /// Loads the store from disk. Cheap enough to call at startup.
  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlayersJson);
    final players = <Player>[];
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        players.add(Player.fromJson(e as Map<String, dynamic>));
      }
    }
    Player? active;
    final activeName = prefs.getString(_kActivePlayer);
    if (activeName != null) {
      for (final p in players) {
        if (p.name == activeName) {
          active = p;
          break;
        }
      }
    }
    return ProfileStore._(prefs, players, active);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kPlayersJson,
      jsonEncode(_players.map((p) => p.toJson()).toList()),
    );
    if (_active != null) {
      await _prefs.setString(_kActivePlayer, _active!.name);
    } else {
      await _prefs.remove(_kActivePlayer);
    }
  }

  /// Adds a new player and makes them active. Trims and validates the name.
  /// Returns null if the name is blank or already taken.
  Future<Player?> createPlayer(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (_players.any((p) => p.name.toLowerCase() == trimmed.toLowerCase())) {
      return null;
    }
    final p = Player(name: trimmed);
    _players.add(p);
    _active = p;
    await _persist();
    notifyListeners();
    return p;
  }

  Future<void> selectPlayer(Player p) async {
    _active = p;
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlayer(Player p) async {
    _players.removeWhere((x) => x.name == p.name);
    if (_active?.name == p.name) {
      _active = _players.isNotEmpty ? _players.first : null;
    }
    await _persist();
    notifyListeners();
  }

  /// Records that the active player solved [levelNumber]. Only advances the
  /// stored progress; never moves it backwards.
  Future<void> recordWin(int levelNumber) async {
    final p = _active;
    if (p == null) return;
    if (levelNumber <= p.lastSolvedLevel) return;
    p.lastSolvedLevel = levelNumber;
    await _persist();
    notifyListeners();
  }
}

/// Inherited-widget vendor for [ProfileStore]. Listens to the store so any
/// descendant calling [of] rebuilds when notify fires.
class ProfileScope extends InheritedNotifier<ProfileStore> {
  const ProfileScope({
    super.key,
    required ProfileStore store,
    required super.child,
  }) : super(notifier: store);

  static ProfileStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    assert(scope != null, 'No ProfileScope found in context');
    return scope!.notifier!;
  }
}
