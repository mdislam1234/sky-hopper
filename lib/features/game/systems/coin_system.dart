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

  void addPlatform(PlatformData platform) {
    // One per alternating platform, centered in a reachable landing/jump area.
    if (_platformNumber++ % GameConfig.coinPlatformInterval == 0) {
      coins.add(
        CoinData(
          platform.x + platform.width / 2,
          platform.y - GameConfig.coinAbovePlatform,
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
