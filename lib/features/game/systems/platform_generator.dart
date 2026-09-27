import 'dart:math';

import '../config/game_config.dart';
import 'difficulty_director.dart';

enum PlatformType { normal, moving, crumbling, spike }

class PlatformData {
  PlatformData(double x, this.y, [this.width = GameConfig.platformWidth])
    : x = x,
      originX = x,
      type = PlatformType.normal,
      movementSpeed = 0,
      movementMinX = x,
      movementMaxX = x,
      spikesOnRight = true;

  PlatformData.typed(
    double x,
    this.y, {
    this.width = GameConfig.platformWidth,
    required this.type,
    this.movementSpeed = 0,
    double movementTravel = 0,
    this.spikesOnRight = true,
  }) : x = x,
       originX = x,
       movementMinX = max(GameConfig.platformMargin, x - movementTravel),
       movementMaxX = min(
         GameConfig.width - width - GameConfig.platformMargin,
         x + movementTravel,
       );

  double x;
  final double originX;
  final double y;
  final double width;
  final PlatformType type;
  final double movementSpeed;
  final double movementMinX;
  final double movementMaxX;
  final bool spikesOnRight;

  int movementDirection = 1;
  bool crumbleActivated = false;
  bool collapsed = false;
  double crumbleElapsed = 0;
  int collapseCount = 0;
  bool nearMissAwarded = false;

  bool get collidable => !collapsed;
  double get spikeWidth =>
      type == PlatformType.spike ? width * GameConfig.spikeWidthFraction : 0;
  double get spikeLeft => spikesOnRight ? x + width - spikeWidth : x;
  double get spikeRight => spikeLeft + spikeWidth;
  double get safeLeft => spikesOnRight ? x : x + spikeWidth;
  double get safeRight => spikesOnRight ? x + width - spikeWidth : x + width;
  double get safeWidth => safeRight - safeLeft;
  double get safeCenter {
    if (type != PlatformType.spike) return x + width / 2;
    return spikesOnRight
        ? x + (width - spikeWidth) / 2
        : x + spikeWidth + (width - spikeWidth) / 2;
  }

  bool get isRisky => type != PlatformType.normal;

  bool overlapsSpikes(double left, double right) =>
      type == PlatformType.spike && right > spikeLeft && left < spikeRight;

  void onLanded() {
    if (type == PlatformType.crumbling && !crumbleActivated && !collapsed) {
      crumbleActivated = true;
    }
  }

  void advance(double dt) {
    if (type == PlatformType.moving && movementMaxX > movementMinX) {
      x += movementDirection * movementSpeed * dt;
      while (x < movementMinX || x > movementMaxX) {
        if (x > movementMaxX) {
          x = movementMaxX - (x - movementMaxX);
          movementDirection = -1;
        } else if (x < movementMinX) {
          x = movementMinX + (movementMinX - x);
          movementDirection = 1;
        }
      }
    }
    if (crumbleActivated && !collapsed) {
      crumbleElapsed += dt;
      if (crumbleElapsed >= GameConfig.crumbleDelay) {
        collapsed = true;
        collapseCount++;
      }
    }
  }
}

class PlatformGenerator {
  PlatformGenerator(this.random);

  final Random random;
  int _safePlatformsRemaining = 0;

  List<PlatformData> initial() => [
    PlatformData(120, 620, 160),
    PlatformData(90, 540),
    PlatformData(160, 460),
    PlatformData(225, 380),
    PlatformData(145, 300),
    PlatformData(75, 220),
    PlatformData(145, 140),
    PlatformData(210, 60),
  ];

  // Reserve 45% of descending-arc flight time for reaction and braking.
  static double horizontalReach(double gap) {
    final speed = -GameConfig.jumpVelocity;
    final time =
        (speed + sqrt(speed * speed - 2 * GameConfig.gravity * gap)) /
        GameConfig.gravity;
    final accelerationTime =
        GameConfig.horizontalMaxSpeed / GameConfig.horizontalAcceleration;
    return GameConfig.horizontalMaxSpeed * (time * 0.55 - accelerationTime);
  }

  PlatformData next(PlatformData previous, {int score = 0}) {
    final gap =
        GameConfig.minGap +
        random.nextDouble() * (GameConfig.maxGap - GameConfig.minGap);
    final reach = min(GameConfig.maxHorizontalStep, horizontalReach(gap));
    final center = previous.safeCenter;
    final x =
        (center +
                (random.nextDouble() * 2 - 1) * reach -
                GameConfig.platformWidth / 2)
            .clamp(
              GameConfig.platformMargin,
              GameConfig.width -
                  GameConfig.platformWidth -
                  GameConfig.platformMargin,
            )
            .toDouble();
    final profile = DifficultyDirector.forScore(score);
    final type = _chooseType(profile);
    final travel = type == PlatformType.moving
        ? min(
            GameConfig.movingPlatformMaxTravel,
            min(
              x - GameConfig.platformMargin,
              GameConfig.width -
                  GameConfig.platformMargin -
                  GameConfig.platformWidth -
                  x,
            ),
          )
        : 0.0;
    final platform = PlatformData.typed(
      x,
      previous.y - gap,
      type: type,
      movementSpeed: type == PlatformType.moving ? profile.movingSpeed : 0,
      movementTravel: travel,
      spikesOnRight: random.nextBool(),
    );
    if (!_isFair(previous, platform, reach)) {
      return PlatformData(x, previous.y - gap);
    }
    if (type != PlatformType.normal) _safePlatformsRemaining = 1;
    return platform;
  }

  PlatformType _chooseType(DifficultyProfile profile) {
    if (_safePlatformsRemaining > 0) {
      _safePlatformsRemaining--;
      return PlatformType.normal;
    }
    final roll = random.nextDouble();
    if (roll < profile.spikeChance) return PlatformType.spike;
    if (roll < profile.spikeChance + profile.crumblingChance) {
      return PlatformType.crumbling;
    }
    if (roll <
        profile.spikeChance + profile.crumblingChance + profile.movingChance) {
      return PlatformType.moving;
    }
    return PlatformType.normal;
  }

  static bool _isFair(
    PlatformData previous,
    PlatformData candidate,
    double reach,
  ) {
    final horizontalDistance = (candidate.safeCenter - previous.safeCenter)
        .abs();
    final motionAllowance = candidate.type == PlatformType.moving
        ? candidate.movementMaxX - candidate.movementMinX
        : 0;
    return candidate.safeWidth >= GameConfig.minimumSafeLandingWidth &&
        horizontalDistance <=
            reach + candidate.safeWidth / 2 - 12 - motionAllowance;
  }
}
