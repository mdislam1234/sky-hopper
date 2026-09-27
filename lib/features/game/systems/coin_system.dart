import '../config/game_config.dart';
import 'platform_generator.dart';

class CoinData {
  CoinData(this.x, this.y);
  final double x;
  final double y;
  bool collected = false;
}

class CoinSystem {
  final List<CoinData> coins = [];
  int collected = 0;
  int _platformNumber = 0;
  int _riskyPlatformNumber = 0;

  void addPlatform(PlatformData platform) {
    // The normal economy stays at one coin per alternating platform.
    if (_platformNumber++ % GameConfig.coinPlatformInterval == 0) {
      coins.add(
        CoinData(
          platform.safeCenter,
          platform.y - GameConfig.coinAbovePlatform,
        ),
      );
    }
    // A single optional bonus makes visibly risky routes worthwhile without
    // making them mandatory or dramatically changing lifetime coin earnings.
    if (!platform.isRisky || _riskyPlatformNumber++ % 4 != 0) return;
    if (platform.type == PlatformType.moving) {
      coins.add(
        CoinData(
          platform.originX + platform.width * 0.75,
          platform.y - GameConfig.coinAbovePlatform - 12,
        ),
      );
    } else if (platform.type == PlatformType.spike) {
      coins.add(
        CoinData(
          (platform.spikesOnRight
              ? platform.originX + platform.width - platform.spikeWidth / 2
              : platform.originX + platform.spikeWidth / 2),
          platform.y - GameConfig.coinAbovePlatform - 8,
        ),
      );
    }
  }

  void collectAt(double x, double y) {
    final r = GameConfig.coinRadius;
    for (final coin in coins) {
      if (coin.collected) continue;
      final nearX = coin.x.clamp(x, x + GameConfig.playerWidth);
      final nearY = coin.y.clamp(y, y + GameConfig.playerHeight);
      final dx = coin.x - nearX;
      final dy = coin.y - nearY;
      if (dx * dx + dy * dy <= r * r) {
        coin.collected = true;
        collected++;
      }
    }
    coins.removeWhere((coin) => coin.collected);
  }

  void cleanup(double cameraTop) => coins.removeWhere(
    (coin) => coin.y > cameraTop + GameConfig.height + GameConfig.cleanupBuffer,
  );
}
