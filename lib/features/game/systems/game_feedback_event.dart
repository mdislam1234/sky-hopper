import 'environment_system.dart';

enum GameFeedbackType {
  bounce,
  coinCollected,
  perfectLanding,
  crumble,
  windEntered,
  stormCloudContact,
  lightningWarning,
  lightningStrike,
  spikeImpact,
  nearMiss,
  biomeChanged,
  approachingBest,
  newPersonalBest,
  gameOver,
}

class GameFeedbackEvent {
  const GameFeedbackEvent(
    this.type, {
    this.x,
    this.y,
    this.streak = 0,
    this.remainingToBest,
    this.biome,
  });

  final GameFeedbackType type;
  final double? x;
  final double? y;
  final int streak;
  final int? remainingToBest;
  final Biome? biome;
}
