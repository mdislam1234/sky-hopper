import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../systems/environment_system.dart';
import '../systems/game_state.dart';

class SkyComponent extends Component {
  SkyComponent(
    this.state, {
    required this.viewportSize,
    required this.viewportScale,
  }) : super(priority: -100);

  final GameState state;
  final Vector2 Function() viewportSize;
  final double Function() viewportScale;
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
  final _visualSize = Vector2.zero();

  void _updatePaints(Vector2 size) {
    if (_visualScore == state.score && _visualSize == size) return;
    _visualScore = state.score;
    _visualSize.setFrom(size);
    final frame = state.environment.frame;
    _sky.shader = Gradient.linear(Offset.zero, Offset(0, size.y), [
      frame.blendColor((value) => value.skyTop),
      frame.blendColor((value) => value.skyBottom),
    ]);
    final cloud = frame.blendColor((value) => value.cloud);
    _cloud.color = cloud.withValues(alpha: 0.44);
    _distantCloud.color = cloud.withValues(alpha: 0.24);
  }

  @override
  void render(Canvas canvas) {
    final size = viewportSize();
    _updatePaints(size);
    canvas.save();
    canvas.scale(viewportScale());
    final frame = state.environment.frame;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _sky);
    _drawCelestial(canvas, frame, size);
    _drawWeather(canvas, frame, size);
    final distantCloudCount = math.max(5, (size.x / 115).ceil());
    for (var i = 0; i < distantCloudCount; i++) {
      final y = (i * 181 - state.cameraTop * 0.08) % (size.y + 130) - 60;
      final x = (i * 173 % (size.x + 140)) - 70;
      canvas.drawOval(Rect.fromLTWH(x, y, 160, 20), _distantCloud);
    }
    final cloudCount = math.max(8, (size.x / 75).ceil());
    for (var i = 0; i < cloudCount; i++) {
      final x = (i * 137 % (size.x + 70)).toDouble() - 35;
      final y = (i * 113 - state.cameraTop * 0.18) % (size.y + 110) - 50;
      canvas.drawOval(Rect.fromLTWH(x - 35, y, 100, 22), _cloud);
      canvas.drawOval(Rect.fromLTWH(x - 10, y - 14, 42, 35), _cloud);
    }
    if (state.hazards.distantFlash) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _flash);
    }
    canvas.restore();
  }

  void _drawCelestial(Canvas canvas, BiomeFrame frame, Vector2 size) {
    final stars = frame.blendValue((value) => value.starDensity);
    final starCount =
        (stars * 34 * size.x / GameConfig.width * size.y / GameConfig.height)
            .round();
    for (var i = 0; i < starCount; i++) {
      final x = ((i * 97 + 31) % size.x).toDouble();
      final y = ((i * 53 + 17 - state.cameraTop * 0.03) % size.y).toDouble();
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.5 : 0.8, _star);
    }
    final celestialX = size.x - 70;
    if (frame.biome == Biome.night || frame.to == Biome.night) {
      _celestial.color = const Color(0xFFEAF3D0).withValues(alpha: 0.84);
      canvas.drawCircle(Offset(celestialX, 98), 25, _celestial);
      _celestial.color = const Color(0xFF18355F);
      canvas.drawCircle(Offset(celestialX + 10, 91), 23, _celestial);
    } else if (frame.biome == Biome.space || frame.to == Biome.space) {
      _celestial.color = const Color(0xFF9479D8).withValues(alpha: 0.72);
      canvas.drawCircle(Offset(celestialX - 5, 92), 37, _celestial);
      _celestial.color = const Color(0xFFCC9BE7).withValues(alpha: 0.42);
      canvas.drawOval(Rect.fromLTWH(celestialX - 50, 84, 90, 14), _celestial);
    }
  }

  void _drawWeather(Canvas canvas, BiomeFrame frame, Vector2 size) {
    final rain = frame.blendValue((value) => value.rainDensity);
    final dropCount = (rain * 24 * size.x / GameConfig.width).round();
    for (var i = 0; i < dropCount; i++) {
      final x = ((i * 67 + 9) % (size.x + 10)).toDouble();
      final y = ((i * 91 - state.cameraTop * 0.45) % (size.y + 30)).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 14), _rain);
    }
  }
}
