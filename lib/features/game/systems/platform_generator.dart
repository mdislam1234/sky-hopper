import 'dart:math';

import '../config/game_config.dart';

class PlatformData {
  const PlatformData(this.x, this.y, [this.width = GameConfig.platformWidth]);
  final double x;
  final double y;
  final double width;
}

class PlatformGenerator {
  PlatformGenerator(this.random);
  final Random random;
  List<PlatformData> initial() => [
    const PlatformData(120, 620, 160),
    const PlatformData(90, 540),
    const PlatformData(160, 460),
    const PlatformData(225, 380),
    const PlatformData(145, 300),
    const PlatformData(75, 220),
    const PlatformData(145, 140),
    const PlatformData(210, 60),
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

  PlatformData next(PlatformData previous) {
    final gap =
        GameConfig.minGap +
        random.nextDouble() * (GameConfig.maxGap - GameConfig.minGap);
    final reach = min(GameConfig.maxHorizontalStep, horizontalReach(gap));
    final center = previous.x + previous.width / 2;
    final x =
        (center +
                (random.nextDouble() * 2 - 1) * reach -
                GameConfig.platformWidth / 2)
            .clamp(
              GameConfig.platformMargin,
              GameConfig.width -
                  GameConfig.platformWidth -
                  GameConfig.platformMargin,
            );
    return PlatformData(x, previous.y - gap);
  }
}
