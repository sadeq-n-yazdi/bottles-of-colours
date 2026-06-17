import 'package:flutter/material.dart';

import '../profile/player.dart';
import '../profile/profile_store.dart';

/// Pick an existing player or create a new one. Used on first launch
/// (forced — no back button), and from the "Change player" button later.
class PlayerPickerScreen extends StatefulWidget {
  const PlayerPickerScreen({super.key, this.forced = false});

  /// When true, hides the back button — used on first launch when there is
  /// no active player yet.
  final bool forced;

  @override
  State<PlayerPickerScreen> createState() => _PlayerPickerScreenState();
}

class _PlayerPickerScreenState extends State<PlayerPickerScreen> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create(ProfileStore store) async {
    final p = await store.createPlayer(_nameCtrl.text);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name is empty or already taken.'),
      ));
      return;
    }
    _nameCtrl.clear();
    if (widget.forced) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(ProfileStore store, Player p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text('Their progress will be lost.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await store.deletePlayer(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProfileScope.of(context);
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: const Text('Who is playing?'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (store.players.isNotEmpty) ...<Widget>[
                  const Text(
                    'Tap a player to continue',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: store.players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = store.players[i];
                        final isActive = store.active?.name == p.name;
                        return Card(
                          color: isActive
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : null,
                          child: ListTile(
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(p.hasFinishedAll
                                ? 'All ${p.lastSolvedLevel} levels solved'
                                : 'Up to level ${p.lastSolvedLevel}'),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(store, p),
                            ),
                            onTap: () async {
                              final nav = Navigator.of(context);
                              await store.selectPlayer(p);
                              if (mounted) nav.pop();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...<Widget>[
                  const Spacer(),
                  const Text(
                    'No players yet.\nCreate one to start playing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const Spacer(),
                ],
                const Divider(height: 32),
                const Text('New player',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _create(store),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _create(store),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
