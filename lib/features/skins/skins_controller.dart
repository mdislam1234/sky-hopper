import 'package:flutter/foundation.dart';

import '../../core/data/data_exception.dart';
import '../auth/auth_controller.dart';
import 'models/skin.dart';

class SkinsController extends ChangeNotifier {
  SkinsController(this.auth, this.owner);
  final AuthController auth;
  final String owner;
  List<Skin> catalog = const [];
  Set<String> owned = {};
  bool loading = true;
  bool busy = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? error;
  bool get active => !_disposed && auth.isCurrentOwner(owner);
  int get coins => auth.profile?.totalCoins ?? 0;
  String? get selected => auth.profile?.selectedSkin;
  bool canUnlock(Skin skin) =>
      !loading && !busy && !owned.contains(skin.id) && coins >= skin.cost;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy || !active) return;
    final generation = ++_loadGeneration;
    loading = true;
    error = null;
    _notify();
    try {
      final store = auth.skinStore;
      if (store == null) throw const DataException(DataError.unavailable);
      final loaded = await Future.wait([
        store.fetchCatalog(),
        store.fetchOwnedSkins(),
      ]).timeout(const Duration(seconds: 15));
      if (!active || generation != _loadGeneration) return;
      catalog = (loaded[0] as List<Skin>);
      // Keep ownership separate from immutable server catalog definitions.
      owned = (loaded[1] as List).map((row) => row.skinId as String).toSet();
      auth.cacheCatalog(owner, catalog);
      await auth.refreshConfirmedProfile(owner);
    } catch (_) {
      if (active) error = 'Skins could not be loaded. Please try again.';
    } finally {
      if (active && generation == _loadGeneration) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> unlock(Skin skin) async {
    if (!active || busy || loading || owned.contains(skin.id)) return;
    if (coins < skin.cost) {
      error = 'Not enough coins.';
      _notify();
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      final result = await auth.unlockSkinFor(owner, skin.id);
      if (active) owned = {...owned, result.skinId};
    } catch (e) {
      if (active) error = e is DataException ? e.message : 'Could not confirm unlock. Refresh or retry; an owned skin is never charged twice.';
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> select(Skin skin) async {
    if (!active || busy || loading || selected == skin.id) return;
    if (!owned.contains(skin.id)) {
      error = 'Unlock this skin before selecting it.';
      _notify();
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await auth.selectSkinFor(owner, skin.id);
    } catch (e) {
      if (active) {
        error = e is DataException
            ? e.message
            : 'Could not confirm selection. Refresh or retry.';
      }
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
