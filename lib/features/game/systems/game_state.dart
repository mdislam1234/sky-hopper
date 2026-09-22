import 'dart:math';

import '../config/game_config.dart';
import 'platform_generator.dart';
import 'coin_system.dart';

enum RunPhase { playing, paused, gameOver }

class HeightScore {
  double maximumHeight = 0;
  int get score => (maximumHeight / GameConfig.scoreScale).floor();
  void observe(double height) => maximumHeight = max(maximumHeight, height);
}

/// Pure fixed-step simulation: no rendering, authentication, or network access.
class GameState {
  GameState({this.seed = 5}) {
    reset();
  }
  final int seed;
  late PlatformGenerator generator;
  late List<PlatformData> platforms;
  late HeightScore progress;
  late CoinSystem coinSystem;
  int get coinsCollected => coinSystem.collected;
  RunPhase phase = RunPhase.playing;
  double x = 0, y = 0, vx = 0, vy = 0, cameraTop = 0;
  double _accumulator = 0;
  int direction = 0;
  int bounces = 0;
  int get score => progress.score;
  void reset() {
    generator = PlatformGenerator(Random(seed));
    platforms = generator.initial();
    coinSystem = CoinSystem();
    platforms.forEach(coinSystem.addPlatform);
    progress = HeightScore();
    x = GameConfig.width / 2 - GameConfig.playerWidth / 2;
    y = GameConfig.startSurface - GameConfig.playerHeight;
    vx = 0;
    vy = GameConfig.jumpVelocity;
    cameraTop = 0;
    direction = 0;
    bounces = 0;
    _accumulator = 0;
    phase = RunPhase.playing;
  }

  void pause() {
    if (phase == RunPhase.playing) phase = RunPhase.paused;
    direction = 0;
    _accumulator = 0;
  }

  void resume() {
    if (phase == RunPhase.paused) phase = RunPhase.playing;
  }

  static double wrap(double x) =>
      (x + GameConfig.playerWidth) %
          (GameConfig.width + GameConfig.playerWidth) -
      GameConfig.playerWidth;
  void advance(double dt) {
    if (phase != RunPhase.playing || !dt.isFinite || dt <= 0) return;
    _accumulator += min(dt, GameConfig.maxFrameTime);
    while (_accumulator + 1e-10 >= GameConfig.fixedStep &&
        phase == RunPhase.playing) {
      _step(GameConfig.fixedStep);
      _accumulator -= GameConfig.fixedStep;
    }
  }

  void _step(double dt) {
    final oldX = x;
    final oldBottom = y + GameConfig.playerHeight;
    if (direction == 0) {
      vx = vx.sign * max(0, vx.abs() - GameConfig.horizontalDrag * dt);
    } else {
      vx =
          (vx + direction.clamp(-1, 1) * GameConfig.horizontalAcceleration * dt)
              .clamp(
                -GameConfig.horizontalMaxSpeed,
                GameConfig.horizontalMaxSpeed,
              );
    }
    final unwrappedX = x + vx * dt;
    x = wrap(unwrappedX);
    vy += GameConfig.gravity * dt;
    y += vy * dt;
    final bottom = y + GameConfig.playerHeight;
    PlatformData? landing;
    if (vy > 0 && bottom > oldBottom) {
      for (final platform in platforms) {
        if (oldBottom > platform.y || bottom < platform.y) continue;
        final fraction = (platform.y - oldBottom) / (bottom - oldBottom);
        // Interpolate before wrapping, never sweep across the whole world.
        final contactX = wrap(oldX + (unwrappedX - oldX) * fraction);
        if (contactX + GameConfig.playerWidth > platform.x &&
            contactX < platform.x + platform.width &&
            (landing == null || platform.y < landing.y)) {
          landing = platform;
        }
      }
    }
    if (landing != null) {
      y = landing.y - GameConfig.playerHeight;
      vy = GameConfig.jumpVelocity;
      bounces++;
    }
    coinSystem.collectAt(x, y);
    progress.observe(GameConfig.startSurface - GameConfig.playerHeight - y);
    cameraTop = min(cameraTop, y - GameConfig.cameraZone);
    while (platforms.last.y > cameraTop - GameConfig.generationBuffer) {
      final next = generator.next(platforms.last);
      platforms.add(next);
      coinSystem.addPlatform(next);
    }
    platforms.removeWhere(
      (p) => p.y > cameraTop + GameConfig.height + GameConfig.cleanupBuffer,
    );
    coinSystem.cleanup(cameraTop);
    if (y > cameraTop + GameConfig.height + GameConfig.fallMargin) {
      phase = RunPhase.gameOver;
      direction = 0;
    }
  }
}
