import 'dart:ui';

import 'package:flame/components.dart';

import '../systems/game_state.dart';

class SkyComponent extends Component {
  SkyComponent(this.state) : super(priority: -100);
  final GameState state;
  final _cloud = Paint()..color = const Color(0x65FFFFFF);
  final _distantCloud = Paint()..color = const Color(0x35FFFFFF);
  final _sky = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 720), [
      const Color(0xFF66C5F4),
      const Color(0xFFB9EDFF),
    ]);
  @override
  void render(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 720), _sky);
    for (var i = 0; i < 5; i++) {
      final y = (i * 181 - state.cameraTop * 0.08) % 850 - 60;
      canvas.drawOval(
        Rect.fromLTWH((i * 173 % 380) - 70, y, 160, 20),
        _distantCloud,
      );
    }
    for (var i = 0; i < 8; i++) {
      final x = (i * 137 % 370).toDouble();
      final y = (i * 113 - state.cameraTop * 0.18) % 820 - 50;
      canvas.drawOval(Rect.fromLTWH(x - 35, y, 100, 22), _cloud);
      canvas.drawOval(Rect.fromLTWH(x - 10, y - 14, 42, 35), _cloud);
    }
  }
}
