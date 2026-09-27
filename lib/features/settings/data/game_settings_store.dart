import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_settings.dart';

abstract interface class GameSettingsStore {
  Future<GameSettings> load();
  Future<void> save(GameSettings settings);
}

class SharedPreferencesGameSettingsStore implements GameSettingsStore {
  SharedPreferencesGameSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _musicKey = 'sky_hopper.music_enabled';
  static const _soundKey = 'sky_hopper.sound_enabled';
  static const _hapticsKey = 'sky_hopper.haptics_enabled';
  final SharedPreferencesAsync _preferences;

  @override
  Future<GameSettings> load() async => GameSettings(
    musicEnabled: await _preferences.getBool(_musicKey) ?? true,
    soundEnabled: await _preferences.getBool(_soundKey) ?? true,
    hapticsEnabled: await _preferences.getBool(_hapticsKey) ?? true,
  );

  @override
  Future<void> save(GameSettings settings) async {
    await Future.wait([
      _preferences.setBool(_musicKey, settings.musicEnabled),
      _preferences.setBool(_soundKey, settings.soundEnabled),
      _preferences.setBool(_hapticsKey, settings.hapticsEnabled),
    ]);
  }
}

class MemoryGameSettingsStore implements GameSettingsStore {
  MemoryGameSettingsStore([this.value = const GameSettings()]);

  GameSettings value;

  @override
  Future<GameSettings> load() async => value;

  @override
  Future<void> save(GameSettings settings) async => value = settings;
}
