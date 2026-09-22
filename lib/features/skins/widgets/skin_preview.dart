import 'package:flutter/material.dart';

import '../models/skin.dart';

/// The same 32 x 38 drawing is used by Flutter previews and the Flame player.
class HopperArt {
  HopperArt(this.appearance)
    : body = (Paint()..color = appearance.primary),
      edge = (Paint()..color = appearance.secondary),
      face = (Paint()..color = appearance.accent);
  final SkinAppearance appearance;
  final Paint body, edge, face;
  final white = Paint()..color = const Color(0xFFFFFFFF);
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromLTRBR(0, 3, 32, 38, const Radius.circular(12)),
      edge,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, 32, 34, const Radius.circular(12)),
      body,
    );
    canvas.drawOval(const Rect.fromLTWH(6, 9, 8, 12), white);
    canvas.drawOval(const Rect.fromLTWH(19, 9, 8, 12), white);
    canvas.drawCircle(const Offset(11, 16), 2.5, face);
    canvas.drawCircle(const Offset(24, 16), 2.5, face);
    canvas.drawRRect(
      RRect.fromLTRBR(12, 25, 22, 28, const Radius.circular(3)),
      face,
    );
    canvas.drawOval(const Rect.fromLTWH(-4, 28, 10, 6), body);
    canvas.drawOval(const Rect.fromLTWH(26, 28, 10, 6), body);
  }
}

class SkinPreview extends StatelessWidget {
  const SkinPreview({required this.appearance, super.key});
  final SkinAppearance appearance;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 80,
    child: CustomPaint(painter: _PreviewPainter(appearance)),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.appearance) : art = HopperArt(appearance);
  final SkinAppearance appearance;
  final HopperArt art;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2 - 24, size.height / 2 - 28.5);
    canvas.scale(1.5);
    art.render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.appearance != appearance;
}
