import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../systems/environment_system.dart';
import '../systems/game_state.dart';

class SkyComponent extends Component {
  SkyComponent(this.state) : super(priority: -100);
  final GameState state;
  final _cloud = Paint();
  final _distantCloud = Paint();
  final _sky = Paint();
  final _star = Paint()..color = const Color(0xFFE9FAFF);
  final _rain = Paint()
    ..color = const Color(0x668FC9E8)
    ..strokeWidth = 1;
  final _celestial = Paint();
  final _flash = Paint()..color = const Color(0x42FFFFFF);
  int _visualScore = -1;

  void _updatePaints() {
    if (_visualScore == state.score) return;
    _visualScore = state.score;
    final frame = state.environment.frame;
    _sky.shader = Gradient.linear(
      Offset.zero,
      const Offset(0, GameConfig.height),
      [
        frame.blendColor((value) => value.skyTop),
        frame.blendColor((value) => value.skyBottom),
      ],
    );
    final cloud = frame.blendColor((value) => value.cloud);
    _cloud.color = cloud.withValues(alpha: 0.44);
    _distantCloud.color = cloud.withValues(alpha: 0.24);
  }

  @override
  void render(Canvas canvas) {
    _updatePaints();
    final frame = state.environment.frame;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height),
      _sky,
    );
    _drawCelestial(canvas, frame);
    _drawWeather(canvas, frame);
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
    if (state.hazards.distantFlash) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height),
        _flash,
      );
    }
  }

  void _drawCelestial(Canvas canvas, BiomeFrame frame) {
    final stars = frame.blendValue((value) => value.starDensity);
    final starCount = (stars * 34).round();
    for (var i = 0; i < starCount; i++) {
      final x = ((i * 97 + 31) % 397).toDouble();
      final y = ((i * 53 + 17 - state.cameraTop * 0.03) % 710).toDouble();
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.5 : 0.8, _star);
    }
    if (frame.biome == Biome.night || frame.to == Biome.night) {
      _celestial.color = const Color(0xFFEAF3D0).withValues(alpha: 0.84);
      canvas.drawCircle(const Offset(330, 98), 25, _celestial);
      _celestial.color = const Color(0xFF18355F);
      canvas.drawCircle(const Offset(340, 91), 23, _celestial);
    } else if (frame.biome == Biome.space || frame.to == Biome.space) {
      _celestial.color = const Color(0xFF9479D8).withValues(alpha: 0.72);
      canvas.drawCircle(const Offset(325, 92), 37, _celestial);
      _celestial.color = const Color(0xFFCC9BE7).withValues(alpha: 0.42);
      canvas.drawOval(const Rect.fromLTWH(280, 84, 90, 14), _celestial);
    }
  }

  void _drawWeather(Canvas canvas, BiomeFrame frame) {
    final rain = frame.blendValue((value) => value.rainDensity);
    final dropCount = (rain * 24).round();
    for (var i = 0; i < dropCount; i++) {
      final x = ((i * 67 + 9) % 410).toDouble();
      final y = ((i * 91 - state.cameraTop * 0.45) % 750).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 14), _rain);
    }
  }
}
