// Explicit gameplay-only development entry point. Production main.dart retains
// its authenticated gate; this harness has no auth identity or backend client.
import 'package:flutter/material.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';

void main() => runApp(
  MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: const _PreviewMenu(),
  ),
);

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => GameScreen(
              preview: true,
              onHome: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        child: const Text('PLAY — OFFLINE GAMEPLAY PREVIEW'),
      ),
    ),
  );
}
