import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import '../auth/auth_controller.dart';
import 'models/skin.dart';
import 'skins_controller.dart';
import 'widgets/skin_preview.dart';

class SkinsScreen extends StatefulWidget {
  const SkinsScreen({required this.auth, required this.onBack, super.key});
  final AuthController auth;
  final VoidCallback onBack;
  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  late final SkinsController _store = SkinsController(
    widget.auth,
    widget.auth.profile!.id,
  );
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<void> _confirm(Skin skin) async {
    if (_confirming || !_store.canUnlock(skin)) return;
    _confirming = true;
    final approved = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Unlock skin?'),
        content: Text('Unlock ${skin.name} for ${skin.cost} coins?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (approved == true && mounted && _store.active) await _store.unlock(skin);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_store, widget.auth]),
    builder: (context, _) => SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  'SKINS',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh skins',
                onPressed: _store.loading || _store.busy ? null : _store.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(
            'Coins: ${_store.coins}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_store.loading)
            const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading skins'),
            )
          else ...[
            if (_store.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(_store.error!, textAlign: TextAlign.center),
              ),
              TextButton(
                onPressed: _store.busy ? null : _store.load,
                child: const Text('Retry'),
              ),
            ],
            if (widget.auth.message != null)
              Text(widget.auth.message!, textAlign: TextAlign.center),
            if (_store.catalog.isEmpty && _store.error == null)
              const Text('No skins available.'),
            for (final skin in _store.catalog) _card(context, skin),
          ],
        ],
      ),
    ),
  );

  Widget _card(BuildContext context, Skin skin) {
    final owned = _store.owned.contains(skin.id);
    final selected = owned && _store.selected == skin.id;
    return Card(
      key: ValueKey('skin-${skin.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SkinPreview(appearance: skin.appearance),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skin.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (skin.description != null) Text(skin.description!),
                    ],
                  ),
                ),
              ],
            ),
            Text(owned ? 'OWNED' : '${skin.cost} coins'),
            const SizedBox(height: 8),
            FilledButton(
              key: ValueKey('action-${skin.id}'),
              onPressed: _store.busy || selected
                  ? null
                  : owned
                  ? () => _store.select(skin)
                  : _store.canUnlock(skin)
                  ? () => _confirm(skin)
                  : null,
              child: Text(
                selected
                    ? 'SELECTED'
                    : owned
                    ? 'SELECT'
                    : 'UNLOCK — ${skin.cost} COINS',
                textAlign: TextAlign.center,
              ),
            ),
            if (!owned && _store.coins < skin.cost)
              const Text('Not enough coins.', textAlign: TextAlign.center),
            if (_store.busy)
              const Text(
                'Confirming with server…',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
