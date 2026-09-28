import 'dart:math';

import '../config/game_config.dart';
import 'coin_system.dart';
import 'difficulty_director.dart';
import 'environment_system.dart';
import 'game_feedback_event.dart';
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
  GameState({this.seed = 5, this.personalBestScore = 0}) {
    reset();
  }
  final int seed;
  final int personalBestScore;
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
  int perfectStreak = 0;
  int perfectLandings = 0;
  int bestPerfectStreak = 0;
  int movingPlatformLandings = 0;
  int nearMisses = 0;
  bool newPersonalBest = false;
  final List<GameFeedbackEvent> _feedbackEvents = [];
  final Set<int> _approachThresholdsFired = {};
  bool _insideWind = false;
  int get score => progress.score;
  int get displayedBestScore => max(personalBestScore, score);
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
    perfectStreak = 0;
    perfectLandings = 0;
    bestPerfectStreak = 0;
    movingPlatformLandings = 0;
    nearMisses = 0;
    newPersonalBest = false;
    _feedbackEvents.clear();
    _approachThresholdsFired.clear();
    _insideWind = false;
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

  List<GameFeedbackEvent> drainFeedbackEvents() {
    if (_feedbackEvents.isEmpty) return const [];
    final drained = List<GameFeedbackEvent>.unmodifiable(_feedbackEvents);
    _feedbackEvents.clear();
    return drained;
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
    final lightningPhases = {
      for (final bolt in hazards.lightning) bolt: bolt.phase,
    };
    hazards.advance(dt);
    for (final bolt in hazards.lightning) {
      final previousPhase = lightningPhases[bolt];
      if (previousPhase != bolt.phase) {
        if (bolt.phase == LightningPhase.warning) {
          _feedbackEvents.add(
            GameFeedbackEvent(
              GameFeedbackType.lightningWarning,
              x: bolt.x,
              y: bolt.y,
            ),
          );
        } else if (bolt.phase == LightningPhase.strike) {
          _feedbackEvents.add(
            GameFeedbackEvent(
              GameFeedbackType.lightningStrike,
              x: bolt.x,
              y: bolt.y,
            ),
          );
        }
      }
    }
    final oldX = x;
    final oldBottom = y + GameConfig.playerHeight;
    final windAcceleration = hazards.windAccelerationAt(
      WorldRect(x, y, GameConfig.playerWidth, GameConfig.playerHeight),
    );
    final insideWind = windAcceleration != 0;
    if (insideWind && !_insideWind) {
      _feedbackEvents.add(
        GameFeedbackEvent(GameFeedbackType.windEntered, x: x, y: y),
      );
    }
    _insideWind = insideWind;
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
        perfectStreak = 0;
        _feedbackEvents.add(
          GameFeedbackEvent(GameFeedbackType.spikeImpact, x: x, y: y),
        );
        _endRun(GameOverCause.spikes);
        return;
      }
      y = landing.y - GameConfig.playerHeight;
      vy = GameConfig.jumpVelocity;
      bounces++;
      _feedbackEvents.add(
        GameFeedbackEvent(GameFeedbackType.bounce, x: x, y: y),
      );
      final landingCenter = landingX + GameConfig.playerWidth / 2;
      final isPerfect =
          (landingCenter - landing.safeCenter).abs() <=
          landing.safeWidth * GameConfig.perfectLandingToleranceFraction;
      if (isPerfect) {
        perfectStreak = min(GameConfig.maximumPerfectStreak, perfectStreak + 1);
        perfectLandings++;
        bestPerfectStreak = max(bestPerfectStreak, perfectStreak);
        _feedbackEvents.add(
          GameFeedbackEvent(
            GameFeedbackType.perfectLanding,
            x: landing.safeCenter,
            y: landing.y,
            streak: perfectStreak,
          ),
        );
      } else {
        perfectStreak = 0;
      }
      if (landing.type == PlatformType.moving) movingPlatformLandings++;
      if (landing.type == PlatformType.spike && !landing.nearMissAwarded) {
        final gap = landing.spikesOnRight
            ? landing.spikeLeft - innerRight
            : innerLeft - landing.spikeRight;
        if (gap >= 0 && gap <= GameConfig.nearMissMargin) {
          landing.nearMissAwarded = true;
          _registerNearMiss(landing.safeCenter, landing.y);
        }
      }
      final crumbleWasActive = landing.crumbleActivated;
      landing.onLanded();
      if (!crumbleWasActive && landing.crumbleActivated) {
        _feedbackEvents.add(
          GameFeedbackEvent(GameFeedbackType.crumble, x: x, y: landing.y),
        );
      }
    }
    final playerBounds = WorldRect(
      x + 3,
      y + 2,
      GameConfig.playerWidth - 6,
      GameConfig.playerHeight - 4,
    );
    final cloudCollision = hazards.collideCloud(playerBounds);
    if (cloudCollision != null) {
      perfectStreak = 0;
      _feedbackEvents.add(
        GameFeedbackEvent(GameFeedbackType.stormCloudContact, x: x, y: y),
      );
      vx = cloudCollision.horizontalVelocity.clamp(
        -GameConfig.horizontalMaxSpeed,
        GameConfig.horizontalMaxSpeed,
      );
      vy = max(vy, cloudCollision.verticalVelocity);
    }
    if (hazards.lightningHits(playerBounds)) {
      perfectStreak = 0;
      _endRun(GameOverCause.lightning);
      return;
    }
    final nearMissCount = hazards.collectNearMisses(playerBounds);
    for (var index = 0; index < nearMissCount; index++) {
      _registerNearMiss(x, y);
    }
    final collectedNow = coinSystem.collectAt(x, y);
    for (var index = 0; index < collectedNow; index++) {
      _feedbackEvents.add(
        GameFeedbackEvent(GameFeedbackType.coinCollected, x: x, y: y),
      );
    }
    final previousScore = score;
    progress.observe(GameConfig.startSurface - GameConfig.playerHeight - y);
    _updatePersonalBest(previousScore);
    if (environment.update(score)) {
      _feedbackEvents.add(
        GameFeedbackEvent(
          GameFeedbackType.biomeChanged,
          biome: environment.biome,
        ),
      );
    }
    cameraTop = min(cameraTop, y - GameConfig.cameraZone);
    while (platforms.last.y > cameraTop - GameConfig.generationBuffer) {
      final previous = platforms.last;
      final next = generator.next(previous, score: score);
      platforms.add(next);
      coinSystem.addPlatform(next);
      if (previous.type == PlatformType.normal &&
          next.type == PlatformType.normal) {
        final lightningBefore = hazards.lightning.length;
        hazards.addBetween(previous, next, difficulty);
        if (hazards.lightning.length > lightningBefore) {
          final bolt = hazards.lightning.last;
          _feedbackEvents.add(
            GameFeedbackEvent(
              GameFeedbackType.lightningWarning,
              x: bolt.x,
              y: bolt.y,
            ),
          );
        }
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
    if (phase == RunPhase.gameOver) return;
    phase = RunPhase.gameOver;
    gameOverCause = cause;
    perfectStreak = 0;
    direction = 0;
    _feedbackEvents.add(
      GameFeedbackEvent(GameFeedbackType.gameOver, x: x, y: y),
    );
  }

  void _registerNearMiss(double eventX, double eventY) {
    nearMisses++;
    _feedbackEvents.add(
      GameFeedbackEvent(GameFeedbackType.nearMiss, x: eventX, y: eventY),
    );
  }

  void _updatePersonalBest(int previousScore) {
    if (personalBestScore > 0 && score <= personalBestScore) {
      final previousRemaining = personalBestScore - previousScore;
      final remaining = personalBestScore - score;
      for (final threshold in GameConfig.approachBestThresholds) {
        if (remaining <= threshold &&
            previousRemaining > threshold &&
            _approachThresholdsFired.add(threshold)) {
          _feedbackEvents.add(
            GameFeedbackEvent(
              GameFeedbackType.approachingBest,
              remainingToBest: threshold,
            ),
          );
        }
      }
    }
    if (!newPersonalBest && score > personalBestScore) {
      newPersonalBest = true;
      _feedbackEvents.add(
        const GameFeedbackEvent(GameFeedbackType.newPersonalBest),
      );
    }
  }
}
