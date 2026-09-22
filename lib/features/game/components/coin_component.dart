import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../systems/coin_system.dart';

class CoinComponent extends PositionComponent {
  CoinComponent(this.data, {this.animate = true})
    : super(position: Vector2(data.x, data.y), priority: 5);
  final CoinData data;
  bool animate;
  double _elapsed = 0;
  @override
  void update(double dt) {
    if (animate) _elapsed = (_elapsed + dt) % 4;
    super.update(dt);
  }

  static final _rim = Paint()..color = const Color(0xFFE59B23);
  static final _gold = Paint()..color = const Color(0xFFFFD45A);
  static final _shine = Paint()..color = const Color(0xFFFFF4BC);
  @override
  void render(Canvas canvas) {
    if (data.collected) return;
    canvas.save();
    if (animate) {
      // Appearance only: collision radius and world position never change.
      canvas.scale(0.78 + 0.22 * math.cos(_elapsed * math.pi), 1);
    }
    final r = GameConfig.coinRadius;
    canvas.drawCircle(Offset.zero, r, _rim);
    canvas.drawCircle(const Offset(0, -1), r - 2, _gold);
    canvas.drawRRect(
      RRect.fromLTRBR(-2, -6, 2, 4, const Radius.circular(2)),
      _shine,
    );
    canvas.drawCircle(const Offset(-5, -5), 2, _shine);
    canvas.restore();
  }
}
