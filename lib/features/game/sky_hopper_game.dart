import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'components/platform_component.dart';
import '../skins/models/skin.dart';
import 'components/coin_component.dart';
import 'systems/coin_system.dart';
import 'components/player_component.dart';
import 'components/sky_component.dart';
import 'config/game_config.dart';
import 'systems/game_state.dart';
import 'systems/platform_generator.dart';

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
  final status = ValueNotifier<(int, RunPhase, int)>((0, RunPhase.playing, 0));
  final Map<CoinData, CoinComponent> _coins = {};
  final Map<PlatformData, PlatformComponent> _platforms = {};
  final Vector2 _cameraPosition = Vector2.zero();
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
        final component = PlatformComponent(data);
        _platforms[data] = component;
        world.add(component);
      }
    }
  }

  @override
  void update(double dt) {
    state.advance(dt);
    _syncPlatforms();
    _cameraPosition.setValues(0, state.cameraTop);
    camera.viewfinder.position = _cameraPosition;
    super.update(dt);
    status.value = (state.score, state.phase, state.coinsCollected);
    if (state.phase == RunPhase.gameOver) pauseEngine();
  }

  void pauseRun() {
    state.pause();
    status.value = (state.score, state.phase, state.coinsCollected);
    pauseEngine();
  }

  void resumeRun() {
    state.resume();
    status.value = (state.score, state.phase, state.coinsCollected);
    if (state.phase == RunPhase.playing) resumeEngine();
  }

  void disposeStatus() => status.dispose();
}
