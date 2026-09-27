import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import '../systems/environment_system.dart';

enum SoundCue {
  bounce('bounce.wav'),
  coin('coin.wav'),
  perfect('perfect.wav'),
  crumble('crumble.wav'),
  hazardImpact('hazard_impact.wav'),
  wind('wind.wav'),
  cloud('cloud.wav'),
  lightningWarning('lightning_warning.wav'),
  lightningStrike('lightning_strike.wav'),
  nearMiss('near_miss.wav'),
  newBest('new_best.wav'),
  gameOver('game_over.wav'),
  uiTap('ui_tap.wav');

  const SoundCue(this.asset);
  final String asset;
}

abstract interface class GameAudioService {
  Future<void> preload();
  Future<void> play(SoundCue cue);
  Future<void> transitionTo(Biome biome);
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  Future<void> stopMusic();
  Future<void> dispose();
}

class SilentGameAudioService implements GameAudioService {
  const SilentGameAudioService();

  @override
  Future<void> preload() async {}
  @override
  Future<void> play(SoundCue cue) async {}
  @override
  Future<void> transitionTo(Biome biome) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> resumeMusic() async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> dispose() async {}
}

class FlameGameAudioService implements GameAudioService {
  final Map<SoundCue, AudioPool> _pools = {};
  final List<AudioPlayer> _musicPlayers = [AudioPlayer(), AudioPlayer()];
  int _activeMusic = 0;
  int _transitionGeneration = 0;
  bool _preloaded = false;
  bool _musicPlaying = false;

  static const _musicAssets = {
    Biome.sunny: 'music_sunny.wav',
    Biome.sunset: 'music_sunset.wav',
    Biome.storm: 'music_storm.wav',
    Biome.night: 'music_night.wav',
    Biome.space: 'music_space.wav',
  };

  @override
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    for (final player in _musicPlayers) {
      player.audioCache = FlameAudio.audioCache;
      await player.setReleaseMode(ReleaseMode.loop);
    }
    await FlameAudio.audioCache.loadAll([
      ...SoundCue.values.map((cue) => cue.asset),
      ..._musicAssets.values,
    ]);
    for (final cue in SoundCue.values) {
      _pools[cue] = await FlameAudio.createPool(
        cue.asset,
        minPlayers: 1,
        maxPlayers: cue == SoundCue.coin ? 3 : 2,
      );
    }
  }

  @override
  Future<void> play(SoundCue cue) async {
    await preload();
    await _pools[cue]?.start(
      volume: switch (cue) {
        SoundCue.wind => 0.24,
        SoundCue.uiTap => 0.3,
        SoundCue.lightningStrike ||
        SoundCue.hazardImpact ||
        SoundCue.gameOver => 0.62,
        _ => 0.48,
      },
    );
  }

  @override
  Future<void> transitionTo(Biome biome) async {
    await preload();
    final generation = ++_transitionGeneration;
    final oldIndex = _activeMusic;
    final nextIndex = 1 - oldIndex;
    final oldPlayer = _musicPlayers[oldIndex];
    final nextPlayer = _musicPlayers[nextIndex];
    await nextPlayer.stop();
    await nextPlayer.setReleaseMode(ReleaseMode.loop);
    await nextPlayer.setVolume(0);
    await nextPlayer.setSource(AssetSource(_musicAssets[biome]!));
    await nextPlayer.resume();
    _musicPlaying = true;
    for (var step = 1; step <= 6; step++) {
      if (generation != _transitionGeneration) return;
      final blend = step / 6;
      await Future.wait([
        nextPlayer.setVolume(0.28 * blend),
        oldPlayer.setVolume(0.28 * (1 - blend)),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 55));
    }
    if (generation != _transitionGeneration) return;
    await oldPlayer.stop();
    _activeMusic = nextIndex;
  }

  @override
  Future<void> pauseMusic() async {
    if (!_musicPlaying) return;
    await _musicPlayers[_activeMusic].pause();
  }

  @override
  Future<void> resumeMusic() async {
    if (!_musicPlaying) return;
    await _musicPlayers[_activeMusic].resume();
  }

  @override
  Future<void> stopMusic() async {
    _transitionGeneration++;
    _musicPlaying = false;
    await Future.wait(_musicPlayers.map((player) => player.stop()));
  }

  @override
  Future<void> dispose() async {
    _transitionGeneration++;
    await Future.wait([
      ..._pools.values.map((pool) => pool.dispose()),
      ..._musicPlayers.map((player) => player.dispose()),
    ]);
    _pools.clear();
  }
}
