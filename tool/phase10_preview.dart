// Development-only Phase 10 inspector. It is never imported by production
// main.dart, has no auth identity, and creates no backend client or writes.
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/coin_system.dart';
import 'package:sky_hopper/features/game/systems/hazard_system.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';

void main() => runApp(
  MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: const _Phase10Preview(),
  ),
);

class _Phase10Preview extends StatefulWidget {
  const _Phase10Preview();

  @override
  State<_Phase10Preview> createState() => _Phase10PreviewState();
}

class _Phase10PreviewState extends State<_Phase10Preview> {
  final game = SkyHopperGame(seed: 1010);
  final focus = FocusNode();
  final pressed = <LogicalKeyboardKey>{};
  int selectedScore = 0;

  @override
  void dispose() {
    game.pauseEngine();
    game.disposeStatus();
    focus.dispose();
    super.dispose();
  }

  void loadStage(int score) {
    selectedScore = score;
    final state = game.state..reset();
    state.progress.observe(score * GameConfig.scoreScale);
    state.environment.update(state.score);
    state.platforms = [
      PlatformData(120, 620, 160),
      score >= GameConfig.movingPlatformScore
          ? PlatformData.typed(
              90,
              540,
              type: PlatformType.moving,
              movementSpeed: 30,
              movementTravel: 22,
            )
          : PlatformData(90, 540),
      score >= GameConfig.crumblingPlatformScore
          ? PlatformData.typed(180, 460, type: PlatformType.crumbling)
          : PlatformData(180, 460),
      score >= GameConfig.spikePlatformScore
          ? PlatformData.typed(
              225,
              380,
              type: PlatformType.spike,
              spikesOnRight: false,
            )
          : PlatformData(225, 380),
      PlatformData(145, 300),
      score >= GameConfig.movingPlatformScore
          ? PlatformData.typed(
              75,
              220,
              type: PlatformType.moving,
              movementSpeed: 36,
              movementTravel: 22,
            )
          : PlatformData(75, 220),
      score >= GameConfig.crumblingPlatformScore
          ? PlatformData.typed(145, 140, type: PlatformType.crumbling)
          : PlatformData(145, 140),
      PlatformData(210, 60),
    ];
    state.coinSystem = CoinSystem();
    for (final platform in state.platforms) {
      state.coinSystem.addPlatform(platform);
    }
    state.hazards = HazardSystem(random: Random(1010));
    if (score >= GameConfig.windScore) {
      state.hazards.windZones.add(
        WindZoneData(
          x: 0,
          y: 270,
          width: GameConfig.windZoneWidth,
          height: 240,
          direction: 1,
          acceleration: state.difficulty.windAcceleration,
        ),
      );
      state.hazards.stormClouds.add(
        StormCloudData(x: 245, y: 485, minX: 220, maxX: 310),
      );
    }
    if (score >= GameConfig.lightningScore) {
      state.hazards.lightning.add(
        LightningData(x: 342, y: 180, height: 360, looping: true),
      );
    }
    game.resumeRun();
    focus.requestFocus();
    setState(() {});
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    const movement = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
    ];
    if (!movement.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      pressed.remove(event.logicalKey);
    } else {
      pressed.add(event.logicalKey);
    }
    final left =
        pressed.contains(LogicalKeyboardKey.arrowLeft) ||
        pressed.contains(LogicalKeyboardKey.keyA);
    final right =
        pressed.contains(LogicalKeyboardKey.arrowRight) ||
        pressed.contains(LogicalKeyboardKey.keyD);
    game.state.direction = (right ? 1 : 0) - (left ? 1 : 0);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Banner(
      message: 'DEV PREVIEW',
      location: BannerLocation.topEnd,
      child: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: onKey,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: GameConfig.width / GameConfig.height,
                child: GameWidget<SkyHopperGame>(game: game, autofocus: false),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 8, 72, 8),
                  child: Row(
                    children: [
                      for (final stage in const [0, 400, 800, 1100, 1400, 1900])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$stage'),
                            selected: selectedScore == stage,
                            onSelected: (_) => loadStage(stage),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ValueListenableBuilder<GameStatus>(
                    valueListenable: game.status,
                    builder: (context, status, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '${game.state.environment.biome.label}  •  '
                          '${status.phase.name.toUpperCase()}  •  '
                          'A/D or ←/→',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
