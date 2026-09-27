import 'package:flutter/foundation.dart';

import 'data/game_settings_store.dart';
import 'models/game_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final GameSettingsStore _store;
  GameSettings value = const GameSettings();
  bool loaded = false;

  Future<void> load() async {
    if (loaded) return;
    try {
      value = await _store.load();
    } catch (_) {
      value = const GameSettings();
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> setMusicEnabled(bool enabled) =>
      _update(value.copyWith(musicEnabled: enabled));
  Future<void> setSoundEnabled(bool enabled) =>
      _update(value.copyWith(soundEnabled: enabled));
  Future<void> setHapticsEnabled(bool enabled) =>
      _update(value.copyWith(hapticsEnabled: enabled));

  Future<void> _update(GameSettings next) async {
    if (next == value) return;
    value = next;
    notifyListeners();
    try {
      await _store.save(next);
    } catch (_) {
      // Settings stay usable for this session if local storage is unavailable.
    }
  }
}
