import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'components/hazard_components.dart';
import 'components/platform_component.dart';
import '../skins/models/skin.dart';
import 'components/coin_component.dart';
import 'systems/coin_system.dart';
import 'components/player_component.dart';
import 'components/sky_component.dart';
import 'config/game_config.dart';
import 'systems/environment_system.dart';
import 'systems/game_state.dart';
import 'systems/hazard_system.dart';
import 'systems/platform_generator.dart';

class GameStatus {
  const GameStatus({
    required this.score,
    required this.phase,
    required this.coins,
    this.cause,
    this.biomeNotice,
  });

  final int score;
  final RunPhase phase;
  final int coins;
  final GameOverCause? cause;
  final Biome? biomeNotice;
}

class SkyHopperGame extends FlameGame {
  SkyHopperGame({int seed = 5, this.appearance = SkinAppearance.defaultSkin})
    : state = GameState(seed: seed),
      super(
        camera: CameraComponent.withFixedResolution(
          width: GameConfig.width,
          height: GameConfig.height,
        ),
      ) {
    debugMode = GameConfig.debug;
    pauseWhenBackgrounded = false;
  }
  final GameState state;
  final SkinAppearance appearance;
  bool visualMotion = true;
  final status = ValueNotifier<GameStatus>(
    const GameStatus(score: 0, phase: RunPhase.playing, coins: 0),
  );
  final Map<CoinData, CoinComponent> _coins = {};
  final Map<PlatformData, PlatformComponent> _platforms = {};
  final Map<WindZoneData, WindZoneComponent> _windZones = {};
  final Map<StormCloudData, StormCloudComponent> _stormClouds = {};
  final Map<LightningData, LightningComponent> _lightning = {};
  final Vector2 _cameraPosition = Vector2.zero();
  Biome _lastBiome = Biome.sunny;
  Biome? _biomeNotice;
  double _biomeNoticeRemaining = 0;
  @override
  Color backgroundColor() => const Color(0xFF75CFFF);
  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.backdrop = SkyComponent(state);
    world.add(PlayerComponent(state, appearance: appearance));
    _syncPlatforms();
  }

  void _syncPlatforms() {
    _coins.removeWhere((data, component) {
      if (state.coinSystem.coins.contains(data)) return false;
      component.removeFromParent();
      return true;
    });
    for (final coin in state.coinSystem.coins) {
      if (!_coins.containsKey(coin)) {
        final component = CoinComponent(coin, animate: visualMotion);
        _coins[coin] = component;
        world.add(component);
      }
      _coins[coin]!.animate = visualMotion;
    }
    _platforms.removeWhere((data, component) {
      if (state.platforms.contains(data)) return false;
      component.removeFromParent();
      return true;
    });
    for (final data in state.platforms) {
      if (!_platforms.containsKey(data)) {
        final component = PlatformComponent(data, state);
        _platforms[data] = component;
        world.add(component);
      }
    }
    _syncHazards<WindZoneData, WindZoneComponent>(
      state.hazards.windZones,
      _windZones,
      WindZoneComponent.new,
    );
    _syncHazards<StormCloudData, StormCloudComponent>(
      state.hazards.stormClouds,
      _stormClouds,
      StormCloudComponent.new,
    );
    _syncHazards<LightningData, LightningComponent>(
      state.hazards.lightning,
      _lightning,
      LightningComponent.new,
    );
  }

  void _syncHazards<D, C extends Component>(
    List<D> data,
    Map<D, C> components,
    C Function(D) create,
  ) {
    components.removeWhere((item, component) {
      if (data.contains(item)) return false;
      component.removeFromParent();
      return true;
    });
    for (final item in data) {
      if (!components.containsKey(item)) {
        final component = create(item);
        components[item] = component;
        world.add(component);
      }
    }
  }

  @override
  void update(double dt) {
    state.advance(dt);
    if (state.environment.biome != _lastBiome) {
      _lastBiome = state.environment.biome;
      _biomeNotice = _lastBiome;
      _biomeNoticeRemaining = GameConfig.biomeNoticeDuration;
    } else if (_biomeNotice != null && state.phase == RunPhase.playing) {
      _biomeNoticeRemaining -= dt;
      if (_biomeNoticeRemaining <= 0) _biomeNotice = null;
    }
    _syncPlatforms();
    _cameraPosition.setValues(0, state.cameraTop);
    camera.viewfinder.position = _cameraPosition;
    super.update(dt);
    _notifyStatus();
    if (state.phase == RunPhase.gameOver) pauseEngine();
  }

  void _notifyStatus() {
    status.value = GameStatus(
      score: state.score,
      phase: state.phase,
      coins: state.coinsCollected,
      cause: state.gameOverCause,
      biomeNotice: _biomeNotice,
    );
  }

  void pauseRun() {
    state.pause();
    _notifyStatus();
    pauseEngine();
  }

  void resumeRun() {
    state.resume();
    _notifyStatus();
    if (state.phase == RunPhase.playing) resumeEngine();
  }

  void disposeStatus() => status.dispose();
}
