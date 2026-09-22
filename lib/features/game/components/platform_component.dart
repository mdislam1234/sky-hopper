import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../systems/platform_generator.dart';

class PlatformComponent extends PositionComponent {
  PlatformComponent(this.data) : super(position: Vector2(data.x, data.y));
  final PlatformData data;
  static final _base = Paint()..color = const Color(0xFF358EAA);
  static final _top = Paint()..color = const Color(0xFFF2FFFA);
  static final _grass = Paint()..color = const Color(0xFF74E1C4);
  static final _shadow = Paint()..color = const Color(0x24123B69);
  @override
  void render(Canvas canvas) {
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
  }
}
