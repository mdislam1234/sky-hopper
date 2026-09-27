import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../systems/game_feedback_event.dart';

class FeedbackParticleComponent extends PositionComponent {
  FeedbackParticleComponent({
    required this.event,
    required bool reducedMotion,
    required Vector2 position,
  }) : particleCount = countFor(event.type, reducedMotion: reducedMotion),
       super(position: position, priority: 12);

  final GameFeedbackEvent event;
  final int particleCount;
  double _elapsed = 0;
  static const _lifetime = 0.58;
  static final _paint = Paint();

  static int countFor(GameFeedbackType type, {required bool reducedMotion}) {
    if (reducedMotion) {
      return switch (type) {
        GameFeedbackType.newPersonalBest => 5,
        GameFeedbackType.perfectLanding || GameFeedbackType.coinCollected => 2,
        _ => 0,
      };
    }
    return switch (type) {
      GameFeedbackType.newPersonalBest => 22,
      GameFeedbackType.perfectLanding => 10,
      GameFeedbackType.coinCollected => 6,
      GameFeedbackType.nearMiss => 5,
      GameFeedbackType.lightningStrike => 8,
      _ => 0,
    };
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _lifetime) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (particleCount == 0) return;
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    _paint.color = _color.withValues(alpha: 1 - progress);
    for (var index = 0; index < particleCount; index++) {
      final angle = index * math.pi * 2 / particleCount + index * 0.37;
      final distance = (10 + index % 4 * 4) * progress;
      canvas.drawCircle(
        Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        2.6 - progress * 1.2,
        _paint,
      );
    }
  }

  Color get _color => switch (event.type) {
    GameFeedbackType.newPersonalBest => const Color(0xFFFFD34E),
    GameFeedbackType.perfectLanding => const Color(0xFF91F4FF),
    GameFeedbackType.coinCollected => const Color(0xFFFFE585),
    GameFeedbackType.nearMiss => const Color(0xFFFF8C9B),
    GameFeedbackType.lightningStrike => const Color(0xFFE7FCFF),
    _ => const Color(0xFFFFFFFF),
  };
}
