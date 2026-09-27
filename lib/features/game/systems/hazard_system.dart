import 'dart:math';

import '../config/game_config.dart';
import 'difficulty_director.dart';
import 'platform_generator.dart';

class WorldRect {
  const WorldRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;
  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(WorldRect other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;

  WorldRect inflate(double margin) => WorldRect(
    left - margin,
    top - margin,
    width + margin * 2,
    height + margin * 2,
  );
}

class WindZoneData {
  WindZoneData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.direction,
    required this.acceleration,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int direction;
  final double acceleration;
  double animationTime = 0;
  WorldRect get bounds => WorldRect(x, y, width, height);

  void advance(double dt) => animationTime += dt;
}

class StormCloudData {
  StormCloudData({
    required this.x,
    required this.y,
    required this.minX,
    required this.maxX,
    this.width = 72,
    this.height = 34,
    this.speed = GameConfig.stormCloudSpeed,
  });

  double x;
  final double y;
  final double minX;
  final double maxX;
  final double width;
  final double height;
  final double speed;
  int direction = 1;
  double collisionCooldown = 0;
  bool nearMissAwarded = false;
  WorldRect get bounds => WorldRect(x, y, width, height);

  void advance(double dt) {
    collisionCooldown = max(0, collisionCooldown - dt);
    if (maxX <= minX) {
      x = minX;
      return;
    }
    x += direction * speed * dt;
    while (x < minX || x > maxX) {
      if (x > maxX) {
        x = maxX - (x - maxX);
        direction = -1;
      } else if (x < minX) {
        x = minX + (minX - x);
        direction = 1;
      }
    }
  }
}

enum LightningPhase { warning, strike, clear, expired }

class LightningData {
  LightningData({
    required this.x,
    required this.y,
    required this.height,
    this.width = GameConfig.lightningWidth,
    this.looping = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final bool looping;
  LightningPhase phase = LightningPhase.warning;
  double phaseElapsed = 0;
  bool nearMissAwarded = false;
  WorldRect get bounds => WorldRect(x, y, width, height);
  bool get isLethal => phase == LightningPhase.strike;

  void advance(double dt) {
    if (phase == LightningPhase.expired) return;
    phaseElapsed += dt;
    while (true) {
      final duration = switch (phase) {
        LightningPhase.warning => GameConfig.lightningWarningDuration,
        LightningPhase.strike => GameConfig.lightningStrikeDuration,
        LightningPhase.clear => GameConfig.lightningClearDuration,
        LightningPhase.expired => double.infinity,
      };
      if (phaseElapsed < duration) return;
      phaseElapsed -= duration;
      phase = switch (phase) {
        LightningPhase.warning => LightningPhase.strike,
        LightningPhase.strike => LightningPhase.clear,
        LightningPhase.clear =>
          looping ? LightningPhase.warning : LightningPhase.expired,
        LightningPhase.expired => LightningPhase.expired,
      };
      if (phase == LightningPhase.expired) return;
    }
  }
}

class CloudCollision {
  const CloudCollision(this.horizontalVelocity, this.verticalVelocity);
  final double horizontalVelocity;
  final double verticalVelocity;
}

class HazardSystem {
  HazardSystem({Random? random}) : random = random ?? Random(1);

  final Random random;
  final List<WindZoneData> windZones = [];
  final List<StormCloudData> stormClouds = [];
  final List<LightningData> lightning = [];
  int _safeSegmentsRemaining = 0;

  bool get distantFlash => lightning.any((bolt) => bolt.isLethal);

  void addBetween(
    PlatformData lower,
    PlatformData upper,
    DifficultyProfile profile,
  ) {
    if (_safeSegmentsRemaining > 0) {
      _safeSegmentsRemaining--;
      return;
    }
    final roll = random.nextDouble();
    if (profile.lightningChance > 0 && roll < profile.lightningChance) {
      _addLightning(lower, upper);
      _safeSegmentsRemaining = 1;
      return;
    }
    if (profile.stormCloudChance > 0 &&
        roll < profile.lightningChance + profile.stormCloudChance) {
      _addStormCloud(lower, upper);
      _safeSegmentsRemaining = 1;
      return;
    }
    if (profile.windChance > 0 &&
        roll <
            profile.lightningChance +
                profile.stormCloudChance +
                profile.windChance) {
      _addWind(lower, upper, profile.windAcceleration);
      _safeSegmentsRemaining = 1;
    }
  }

  void _addWind(PlatformData lower, PlatformData upper, double acceleration) {
    final onLeft = random.nextBool();
    windZones.add(
      WindZoneData(
        x: onLeft ? 0 : GameConfig.width - GameConfig.windZoneWidth,
        y: upper.y - 12,
        width: GameConfig.windZoneWidth,
        height: max(70, lower.y - upper.y + 24),
        direction: onLeft ? 1 : -1,
        acceleration: acceleration,
      ),
    );
  }

  void _addStormCloud(PlatformData lower, PlatformData upper) {
    final onLeft = random.nextBool();
    const rangeWidth = 112.0;
    final minX = onLeft ? 8.0 : GameConfig.width - rangeWidth - 8;
    stormClouds.add(
      StormCloudData(
        x: minX + random.nextDouble() * 30,
        y: (lower.y + upper.y) / 2 - 28,
        minX: minX,
        maxX: minX + rangeWidth - 72,
      ),
    );
  }

  void _addLightning(PlatformData lower, PlatformData upper) {
    final onLeft = random.nextBool();
    lightning.add(
      LightningData(
        x: onLeft ? 22 : GameConfig.width - GameConfig.lightningWidth - 22,
        y: upper.y - 55,
        height: lower.y - upper.y + 110,
        looping: true,
      ),
    );
  }

  void advance(double dt) {
    for (final zone in windZones) {
      zone.advance(dt);
    }
    for (final cloud in stormClouds) {
      cloud.advance(dt);
    }
    for (final bolt in lightning) {
      bolt.advance(dt);
    }
  }

  double windAccelerationAt(WorldRect player) {
    var result = 0.0;
    for (final zone in windZones) {
      if (zone.bounds.overlaps(player)) {
        result += zone.direction * zone.acceleration;
      }
    }
    return result;
  }

  CloudCollision? collideCloud(WorldRect player) {
    for (final cloud in stormClouds) {
      if (cloud.collisionCooldown <= 0 && cloud.bounds.overlaps(player)) {
        cloud.collisionCooldown = GameConfig.stormCloudCollisionCooldown;
        cloud.nearMissAwarded = true;
        final playerCenter = player.left + player.width / 2;
        final cloudCenter = cloud.x + cloud.width / 2;
        final direction = playerCenter < cloudCenter ? -1 : 1;
        return CloudCollision(
          direction * GameConfig.stormCloudKnockbackX,
          GameConfig.stormCloudKnockbackY,
        );
      }
    }
    return null;
  }

  bool lightningHits(WorldRect player) {
    for (final bolt in lightning) {
      if (bolt.isLethal && bolt.bounds.overlaps(player)) {
        bolt.nearMissAwarded = true;
        return true;
      }
    }
    return false;
  }

  int collectNearMisses(WorldRect player) {
    var count = 0;
    for (final cloud in stormClouds) {
      if (!cloud.nearMissAwarded &&
          !cloud.bounds.overlaps(player) &&
          cloud.bounds.inflate(GameConfig.nearMissMargin).overlaps(player)) {
        cloud.nearMissAwarded = true;
        count++;
      }
    }
    for (final bolt in lightning) {
      if (!bolt.nearMissAwarded &&
          bolt.phase == LightningPhase.strike &&
          !bolt.bounds.overlaps(player) &&
          bolt.bounds.inflate(GameConfig.nearMissMargin).overlaps(player)) {
        bolt.nearMissAwarded = true;
        count++;
      }
    }
    return count;
  }

  void cleanup(double cameraTop) {
    final cutoff = cameraTop + GameConfig.height + GameConfig.cleanupBuffer;
    windZones.removeWhere((zone) => zone.y > cutoff);
    stormClouds.removeWhere((cloud) => cloud.y > cutoff);
    lightning.removeWhere((bolt) => bolt.y > cutoff);
  }
}
