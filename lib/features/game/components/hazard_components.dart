import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../systems/hazard_system.dart';

class WindZoneComponent extends PositionComponent {
  WindZoneComponent(this.data)
    : super(position: Vector2(data.x, data.y), priority: 2);

  final WindZoneData data;
  static final _wash = Paint()..color = const Color(0x227BE7FF);
  static final _line = Paint()
    ..color = const Color(0x997BE7FF)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, data.width, data.height, const Radius.circular(16)),
      _wash,
    );
    for (var row = 0; row < 4; row++) {
      final y = (18 + row * 24).toDouble();
      final phase = (data.animationTime * 38 + row * 21) % 52;
      final start = data.direction > 0 ? phase - 18 : data.width - phase + 18;
      final end = start + data.direction * 24;
      canvas.drawLine(Offset(start, y), Offset(end, y), _line);
      canvas.drawLine(
        Offset(end, y),
        Offset(end - data.direction * 7, y - 5),
        _line,
      );
      canvas.drawLine(
        Offset(end, y),
        Offset(end - data.direction * 7, y + 5),
        _line,
      );
    }
  }
}

class StormCloudComponent extends PositionComponent {
  StormCloudComponent(this.data)
    : super(position: Vector2(data.x, data.y), priority: 3);

  final StormCloudData data;
  static final _dark = Paint()..color = const Color(0xE23D465B);
  static final _light = Paint()..color = const Color(0xDD667087);
  static final _spark = Paint()..color = const Color(0xFFFFD454);

  @override
  void update(double dt) {
    position.x = data.x;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, 12, data.width, 22), _dark);
    canvas.drawCircle(const Offset(22, 15), 15, _light);
    canvas.drawCircle(const Offset(45, 12), 19, _dark);
    canvas.drawCircle(const Offset(60, 18), 12, _light);
    final bolt = Path()
      ..moveTo(data.width / 2, 28)
      ..lineTo(data.width / 2 - 7, 42)
      ..lineTo(data.width / 2, 40)
      ..lineTo(data.width / 2 - 3, 51)
      ..lineTo(data.width / 2 + 10, 36)
      ..lineTo(data.width / 2 + 3, 37)
      ..close();
    canvas.drawPath(bolt, _spark);
  }
}

class LightningComponent extends PositionComponent {
  LightningComponent(this.data)
    : super(position: Vector2(data.x, data.y), priority: 4);

  final LightningData data;
  static final _warning = Paint()..color = const Color(0x55FFF07A);
  static final _strike = Paint()..color = const Color(0xFFEFFFFF);
  static final _core = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void render(Canvas canvas) {
    switch (data.phase) {
      case LightningPhase.warning:
        final pulse = 0.45 + math.sin(data.phaseElapsed * 18).abs() * 0.4;
        _warning.color = const Color(0xFFFFEF76).withValues(alpha: pulse);
        canvas.drawRect(Rect.fromLTWH(0, 0, data.width, data.height), _warning);
        break;
      case LightningPhase.strike:
        canvas.drawRect(Rect.fromLTWH(0, 0, data.width, data.height), _strike);
        canvas.drawRect(
          Rect.fromLTWH(data.width * 0.38, 0, data.width * 0.24, data.height),
          _core,
        );
        break;
      case LightningPhase.clear:
      case LightningPhase.expired:
        break;
    }
  }
}
