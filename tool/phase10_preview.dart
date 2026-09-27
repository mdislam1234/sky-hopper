// Development-only Phase 10/11 inspector. It is never imported by production
// main.dart, has no auth identity, and creates no backend client or writes.
import 'dart:math';
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/coin_system.dart';
import 'package:sky_hopper/features/game/systems/hazard_system.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/game/audio/game_audio_service.dart';
import 'package:sky_hopper/features/game/audio/game_feedback_controller.dart';
import 'package:sky_hopper/features/game/audio/haptics_service.dart';
import 'package:sky_hopper/features/game/systems/game_feedback_event.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/settings/data/game_settings_store.dart';
import 'package:sky_hopper/features/settings/settings_controller.dart';

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
  final settings = SettingsController(MemoryGameSettingsStore());
  late final feedback = GameFeedbackController(
    settings: settings,
    audio: FlameGameAudioService(),
    haptics: const SystemHapticsService(),
  );
  int selectedScore = 0;
  String previewFeedback = 'READY';

  @override
  void initState() {
    super.initState();
    unawaited(_initializeFeedback());
  }

  Future<void> _initializeFeedback() async {
    await settings.load();
    await feedback.start();
  }

  @override
  void dispose() {
    game.pauseEngine();
    game.disposeStatus();
    unawaited(feedback.dispose());
    settings.dispose();
    focus.dispose();
    super.dispose();
  }

  void loadStage(int score) {
    feedback.userGesture();
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
    feedback.handle([
      GameFeedbackEvent(
        GameFeedbackType.biomeChanged,
        biome: state.environment.biome,
      ),
    ]);
    focus.requestFocus();
    setState(() {});
  }

  void trigger(GameFeedbackEvent event, String label) {
    feedback.userGesture();
    feedback.handle([event]);
    setState(() => previewFeedback = label);
    focus.requestFocus();
  }

  Future<void> setMusic(bool enabled) async {
    feedback.userGesture();
    await settings.setMusicEnabled(enabled);
    if (mounted) setState(() {});
  }

  Future<void> setSound(bool enabled) async {
    feedback.userGesture();
    await settings.setSoundEnabled(enabled);
    if (mounted) setState(() {});
  }

  Future<void> togglePause() async {
    feedback.userGesture();
    if (game.state.phase == RunPhase.paused) {
      game.resumeRun();
      await feedback.resume();
      previewFeedback = 'RESUMED';
    } else {
      game.pauseRun();
      await feedback.pause();
      previewFeedback = 'PAUSED';
    }
    if (mounted) setState(() {});
  }

  Future<void> restartPreview() async {
    feedback.userGesture();
    await feedback.restart();
    loadStage(selectedScore);
    previewFeedback = 'RESTARTED';
    if (mounted) setState(() {});
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final stage in const [
                            0,
                            400,
                            800,
                            1100,
                            1400,
                            1900,
                          ])
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('PERFECT ×3'),
                            onPressed: () => trigger(
                              const GameFeedbackEvent(
                                GameFeedbackType.perfectLanding,
                                streak: 3,
                              ),
                              'PERFECT ×3',
                            ),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('NEAR MISS'),
                            onPressed: () => trigger(
                              const GameFeedbackEvent(
                                GameFeedbackType.nearMiss,
                              ),
                              'CLOSE!',
                            ),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('NEW BEST'),
                            onPressed: () => trigger(
                              const GameFeedbackEvent(
                                GameFeedbackType.newPersonalBest,
                              ),
                              'NEW BEST!',
                            ),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('GAME OVER'),
                            onPressed: () => trigger(
                              const GameFeedbackEvent(
                                GameFeedbackType.gameOver,
                              ),
                              'GAME OVER',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('MUSIC'),
                            selected: settings.value.musicEnabled,
                            onSelected: (enabled) =>
                                unawaited(setMusic(enabled)),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('SFX'),
                            selected: settings.value.soundEnabled,
                            onSelected: (enabled) =>
                                unawaited(setSound(enabled)),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: Text(
                              game.state.phase == RunPhase.paused
                                  ? 'RESUME'
                                  : 'PAUSE',
                            ),
                            onPressed: () => unawaited(togglePause()),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('RESTART'),
                            onPressed: () => unawaited(restartPreview()),
                          ),
                        ],
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
                          '$previewFeedback  •  '
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
