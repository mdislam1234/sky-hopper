import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../systems/game_state.dart';
import '../systems/platform_generator.dart';

class PlatformComponent extends PositionComponent {
  PlatformComponent(this.data, this.state)
    : super(position: Vector2(data.x, data.y));

  final PlatformData data;
  final GameState state;
  static final _base = Paint();
  static final _top = Paint();
  static final _grass = Paint();
  static final _shadow = Paint()..color = const Color(0x24123B69);
  static final _detail = Paint()
    ..color = const Color(0xFFE7F9FF)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final _spike = Paint()..color = const Color(0xFFEF525F);

  @override
  void update(double dt) {
    position.x = data.x;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (data.collapsed) return;
    final frame = state.environment.frame;
    _base.color = frame.blendColor((value) => value.platformBase);
    _grass.color = frame.blendColor((value) => value.platformTop);
    _top.color = Color.lerp(_grass.color, const Color(0xFFFFFFFF), 0.55)!;
    canvas.drawRRect(
      RRect.fromLTRBR(
        3,
        5,
        data.width + 3,
        GameConfig.platformHeight + 5,
        const Radius.circular(8),
      ),
      _shadow,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        0,
        data.width,
        GameConfig.platformHeight,
        const Radius.circular(8),
      ),
      _base,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, data.width, 8, const Radius.circular(5)),
      _grass,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(5, 0, data.width - 5, 3, const Radius.circular(2)),
      _top,
    );
    switch (data.type) {
      case PlatformType.normal:
        break;
      case PlatformType.moving:
        _drawMovingTrim(canvas);
        break;
      case PlatformType.crumbling:
        _drawCracks(canvas);
        break;
      case PlatformType.spike:
        _drawSpikes(canvas);
        break;
    }
  }

  void _drawMovingTrim(Canvas canvas) {
    _detail.color = const Color(0xFFE8FBFF);
    for (var center = 22.0; center < data.width - 14; center += 30) {
      canvas.drawLine(Offset(center - 7, 12), Offset(center, 8), _detail);
      canvas.drawLine(Offset(center, 8), Offset(center + 7, 12), _detail);
    }
  }

  void _drawCracks(Canvas canvas) {
    _detail.color = data.crumbleActivated
        ? const Color(0xFF542E3C)
        : const Color(0xFF6A5260);
    _detail.strokeWidth = data.crumbleActivated ? 2.5 : 1.8;
    canvas.drawLine(
      Offset(data.width * 0.28, 1),
      Offset(data.width * 0.37, 8),
      _detail,
    );
    canvas.drawLine(
      Offset(data.width * 0.37, 8),
      Offset(data.width * 0.3, 15),
      _detail,
    );
    canvas.drawLine(
      Offset(data.width * 0.65, 1),
      Offset(data.width * 0.58, 7),
      _detail,
    );
    canvas.drawLine(
      Offset(data.width * 0.58, 7),
      Offset(data.width * 0.69, 14),
      _detail,
    );
  }

  void _drawSpikes(Canvas canvas) {
    const count = 4;
    final localStart = data.spikesOnRight ? data.width - data.spikeWidth : 0.0;
    final segment = data.spikeWidth / count;
    for (var i = 0; i < count; i++) {
      final left = localStart + i * segment;
      final path = Path()
        ..moveTo(left, 1)
        ..lineTo(left + segment / 2, -10)
        ..lineTo(left + segment, 1)
        ..close();
      canvas.drawPath(path, _spike);
    }
  }
}
