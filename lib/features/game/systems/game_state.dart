import 'dart:math';

import '../config/game_config.dart';
import 'coin_system.dart';
import 'difficulty_director.dart';
import 'environment_system.dart';
import 'hazard_system.dart';
import 'platform_generator.dart';

enum RunPhase { playing, paused, gameOver }

enum GameOverCause { fall, spikes, lightning }

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
  late HazardSystem hazards;
  late EnvironmentState environment;
  int get coinsCollected => coinSystem.collected;
  RunPhase phase = RunPhase.playing;
  GameOverCause? gameOverCause;
  double x = 0, y = 0, vx = 0, vy = 0, cameraTop = 0;
  double _accumulator = 0;
  int direction = 0;
  int bounces = 0;
  int get score => progress.score;
  DifficultyProfile get difficulty => DifficultyDirector.forScore(score);

  void reset() {
    generator = PlatformGenerator(Random(seed));
    platforms = generator.initial();
    coinSystem = CoinSystem();
    platforms.forEach(coinSystem.addPlatform);
    hazards = HazardSystem(random: Random(seed ^ 0x5A17));
    environment = EnvironmentState();
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
    gameOverCause = null;
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
    for (final platform in platforms) {
      platform.advance(dt);
    }
    hazards.advance(dt);
    final oldX = x;
    final oldBottom = y + GameConfig.playerHeight;
    final windAcceleration = hazards.windAccelerationAt(
      WorldRect(x, y, GameConfig.playerWidth, GameConfig.playerHeight),
    );
    if (direction == 0) {
      vx = vx.sign * max(0, vx.abs() - GameConfig.horizontalDrag * dt);
    } else {
      vx += direction.clamp(-1, 1) * GameConfig.horizontalAcceleration * dt;
    }
    vx = (vx + windAcceleration * dt).clamp(
      -GameConfig.horizontalMaxSpeed,
      GameConfig.horizontalMaxSpeed,
    );
    final unwrappedX = x + vx * dt;
    x = wrap(unwrappedX);
    vy += GameConfig.gravity * dt;
    y += vy * dt;
    final bottom = y + GameConfig.playerHeight;
    PlatformData? landing;
    double landingX = x;
    if (vy > 0 && bottom > oldBottom) {
      for (final platform in platforms) {
        if (!platform.collidable) continue;
        if (oldBottom > platform.y || bottom < platform.y) continue;
        final fraction = (platform.y - oldBottom) / (bottom - oldBottom);
        // Interpolate before wrapping, never sweep across the whole world.
        final contactX = wrap(oldX + (unwrappedX - oldX) * fraction);
        if (contactX + GameConfig.playerWidth > platform.x &&
            contactX < platform.x + platform.width &&
            (landing == null || platform.y < landing.y)) {
          landing = platform;
          landingX = contactX;
        }
      }
    }
    if (landing != null) {
      final innerLeft = landingX + 4;
      final innerRight = landingX + GameConfig.playerWidth - 4;
      if (landing.overlapsSpikes(innerLeft, innerRight)) {
        _endRun(GameOverCause.spikes);
        return;
      }
      y = landing.y - GameConfig.playerHeight;
      vy = GameConfig.jumpVelocity;
      bounces++;
      landing.onLanded();
    }
    final playerBounds = WorldRect(
      x + 3,
      y + 2,
      GameConfig.playerWidth - 6,
      GameConfig.playerHeight - 4,
    );
    final cloudCollision = hazards.collideCloud(playerBounds);
    if (cloudCollision != null) {
      vx = cloudCollision.horizontalVelocity.clamp(
        -GameConfig.horizontalMaxSpeed,
        GameConfig.horizontalMaxSpeed,
      );
      vy = max(vy, cloudCollision.verticalVelocity);
    }
    if (hazards.lightningHits(playerBounds)) {
      _endRun(GameOverCause.lightning);
      return;
    }
    coinSystem.collectAt(x, y);
    progress.observe(GameConfig.startSurface - GameConfig.playerHeight - y);
    environment.update(score);
    cameraTop = min(cameraTop, y - GameConfig.cameraZone);
    while (platforms.last.y > cameraTop - GameConfig.generationBuffer) {
      final previous = platforms.last;
      final next = generator.next(previous, score: score);
      platforms.add(next);
      coinSystem.addPlatform(next);
      if (previous.type == PlatformType.normal &&
          next.type == PlatformType.normal) {
        hazards.addBetween(previous, next, difficulty);
      }
    }
    platforms.removeWhere(
      (p) => p.y > cameraTop + GameConfig.height + GameConfig.cleanupBuffer,
    );
    coinSystem.cleanup(cameraTop);
    hazards.cleanup(cameraTop);
    if (y > cameraTop + GameConfig.height + GameConfig.fallMargin) {
      _endRun(GameOverCause.fall);
    }
  }

  void _endRun(GameOverCause cause) {
    phase = RunPhase.gameOver;
    gameOverCause = cause;
    direction = 0;
  }
}
