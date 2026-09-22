// Reproducible original artwork. Run: flutter test tool/generate_web_icons.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/skins/models/skin.dart';
import 'package:sky_hopper/features/skins/widgets/skin_preview.dart';

void main() {
  test('Generate original Sky Hopper Web icons', () async {
    for (final entry in <String, int>{
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'web/icons/apple-touch-icon.png': 180,
      'web/favicon.png': 32,
    }.entries) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(entry.value / 512);
      final background = ui.Paint()
        ..shader = ui.Gradient.linear(ui.Offset.zero, const ui.Offset(0, 512), [
          const ui.Color(0xFF75CFFF),
          const ui.Color(0xFFEAF8FF),
        ]);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 512, 512), background);
      if (entry.value > 32) {
        final cloud = ui.Paint()..color = const ui.Color(0xCCFFFFFF);
        canvas.drawOval(const ui.Rect.fromLTWH(-40, 100, 210, 70), cloud);
        canvas.drawOval(const ui.Rect.fromLTWH(22, 60, 98, 108), cloud);
        canvas.drawOval(const ui.Rect.fromLTWH(355, 280, 220, 65), cloud);
        final platform = ui.Paint()..color = const ui.Color(0xFF299C84);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTWH(146, 355, 220, 24),
            const ui.Radius.circular(12),
          ),
          platform,
        );
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTWH(146, 355, 220, 9),
            const ui.Radius.circular(5),
          ),
          ui.Paint()..color = const ui.Color(0xFFB6FFE1),
        );
      }
      // Foreground fits the central 80%-diameter maskable safe circle.
      canvas.translate(160, 130);
      canvas.scale(6);
      HopperArt(SkinAppearance.defaultSkin).render(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(entry.value, entry.value);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(entry.key).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
