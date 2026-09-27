import '../config/game_config.dart';

class DifficultyProfile {
  const DifficultyProfile({
    required this.movingChance,
    required this.crumblingChance,
    required this.spikeChance,
    required this.windChance,
    required this.stormCloudChance,
    required this.lightningChance,
    required this.movingSpeed,
    required this.windAcceleration,
  });

  final double movingChance;
  final double crumblingChance;
  final double spikeChance;
  final double windChance;
  final double stormCloudChance;
  final double lightningChance;
  final double movingSpeed;
  final double windAcceleration;

  Iterable<double> get probabilities => [
    movingChance,
    crumblingChance,
    spikeChance,
    windChance,
    stormCloudChance,
    lightningChance,
  ];
}

abstract final class DifficultyDirector {
  static DifficultyProfile forScore(int score) {
    if (score < GameConfig.movingPlatformScore) {
      return const DifficultyProfile(
        movingChance: 0,
        crumblingChance: 0,
        spikeChance: 0,
        windChance: 0,
        stormCloudChance: 0,
        lightningChance: 0,
        movingSpeed: GameConfig.movingPlatformMinSpeed,
        windAcceleration: GameConfig.windMinAcceleration,
      );
    }
    if (score < GameConfig.crumblingPlatformScore) {
      return const DifficultyProfile(
        movingChance: 0.14,
        crumblingChance: 0,
        spikeChance: 0,
        windChance: 0,
        stormCloudChance: 0,
        lightningChance: 0,
        movingSpeed: 25,
        windAcceleration: GameConfig.windMinAcceleration,
      );
    }
    if (score < GameConfig.windScore) {
      return const DifficultyProfile(
        movingChance: 0.18,
        crumblingChance: 0.11,
        spikeChance: 0,
        windChance: 0,
        stormCloudChance: 0,
        lightningChance: 0,
        movingSpeed: 28,
        windAcceleration: GameConfig.windMinAcceleration,
      );
    }
    if (score < GameConfig.spikePlatformScore) {
      return const DifficultyProfile(
        movingChance: 0.2,
        crumblingChance: 0.13,
        spikeChance: 0,
        windChance: 0.14,
        stormCloudChance: 0.1,
        lightningChance: 0,
        movingSpeed: 31,
        windAcceleration: 260,
      );
    }
    if (score < GameConfig.lightningScore) {
      return const DifficultyProfile(
        movingChance: 0.22,
        crumblingChance: 0.14,
        spikeChance: 0.09,
        windChance: 0.17,
        stormCloudChance: 0.12,
        lightningChance: 0,
        movingSpeed: 34,
        windAcceleration: 300,
      );
    }
    if (score < GameConfig.highDifficultyScore) {
      return const DifficultyProfile(
        movingChance: 0.24,
        crumblingChance: 0.15,
        spikeChance: 0.11,
        windChance: 0.18,
        stormCloudChance: 0.14,
        lightningChance: 0.09,
        movingSpeed: 37,
        windAcceleration: 350,
      );
    }
    return const DifficultyProfile(
      movingChance: 0.26,
      crumblingChance: 0.17,
      spikeChance: 0.13,
      windChance: 0.2,
      stormCloudChance: 0.16,
      lightningChance: 0.12,
      movingSpeed: GameConfig.movingPlatformMaxSpeed,
      windAcceleration: GameConfig.windMaxAcceleration,
    );
  }
}
