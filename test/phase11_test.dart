import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/game/audio/game_audio_service.dart';
import 'package:sky_hopper/features/game/audio/game_feedback_controller.dart';
import 'package:sky_hopper/features/game/audio/haptics_service.dart';
import 'package:sky_hopper/features/game/components/feedback_particle_component.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/environment_system.dart';
import 'package:sky_hopper/features/game/systems/game_feedback_event.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/systems/hazard_system.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/game/widgets/game_over_overlay.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/game/systems/run_save_controller.dart';
import 'package:sky_hopper/features/settings/data/game_settings_store.dart';
import 'package:sky_hopper/features/settings/models/game_settings.dart';
import 'package:sky_hopper/features/settings/settings_controller.dart';
import 'package:sky_hopper/features/settings/settings_screen.dart';

class FakeAudioService implements GameAudioService {
  int preloads = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  int disposals = 0;
  final List<SoundCue> sounds = [];
  final List<Biome> biomes = [];
  int transitionFailures = 0;

  @override
  Future<void> preload() async => preloads++;
  @override
  Future<void> play(SoundCue cue) async => sounds.add(cue);
  @override
  Future<void> transitionTo(Biome biome) async {
    biomes.add(biome);
    if (transitionFailures > 0) {
      transitionFailures--;
      throw StateError('simulated autoplay block');
    }
  }

  @override
  Future<void> pauseMusic() async => pauses++;
  @override
  Future<void> resumeMusic() async => resumes++;
  @override
  Future<void> stopMusic() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

class FakeHapticsService implements HapticsService {
  final List<HapticCue> cues = [];

  @override
  Future<void> trigger(HapticCue cue) async => cues.add(cue);
}

GameFeedbackController feedbackHarness({
  required SettingsController settings,
  required FakeAudioService audio,
  required FakeHapticsService haptics,
}) =>
    GameFeedbackController(settings: settings, audio: audio, haptics: haptics);

void land(GameState state, PlatformData platform, double playerX) {
  state
    ..platforms = [platform]
    ..x = playerX
    ..y = platform.y - GameConfig.playerHeight - 1
    ..vy = 500;
  state.advance(GameConfig.fixedStep);
}

void climbTo(GameState state, int score) {
  state
    ..y =
        GameConfig.startSurface -
        GameConfig.playerHeight -
        (score + 0.5) * GameConfig.scoreScale
    ..vy = -1;
  state.advance(GameConfig.fixedStep);
}

List<GameFeedbackEvent> eventsOf(
  List<GameFeedbackEvent> events,
  GameFeedbackType type,
) => events.where((event) => event.type == type).toList();

// Lets the signed flutter_tester fallback run one widget test at a time on
// Windows machines where Application Control blocks the Flutter test driver.
const _selectedWidgetTest = String.fromEnvironment('PHASE11_WIDGET_TEST');
bool _runWidgetTest(String name) =>
    _selectedWidgetTest.isEmpty || _selectedWidgetTest == name;

void main() {
  group('device settings', () {
    test('defaults enable music, sound and haptics', () {
      expect(const GameSettings(), const GameSettings());
      expect(const GameSettings().musicEnabled, isTrue);
      expect(const GameSettings().soundEnabled, isTrue);
      expect(const GameSettings().hapticsEnabled, isTrue);
    });

    test('music toggles independently', () async {
      final controller = SettingsController(MemoryGameSettingsStore());
      await controller.load();
      await controller.setMusicEnabled(false);
      expect(controller.value.musicEnabled, isFalse);
      expect(controller.value.soundEnabled, isTrue);
      expect(controller.value.hapticsEnabled, isTrue);
    });

    test('sound effects toggle independently', () async {
      final controller = SettingsController(MemoryGameSettingsStore());
      await controller.load();
      await controller.setSoundEnabled(false);
      expect(controller.value.musicEnabled, isTrue);
      expect(controller.value.soundEnabled, isFalse);
      expect(controller.value.hapticsEnabled, isTrue);
    });

    test('haptics toggle independently', () async {
      final controller = SettingsController(MemoryGameSettingsStore());
      await controller.load();
      await controller.setHapticsEnabled(false);
      expect(controller.value.musicEnabled, isTrue);
      expect(controller.value.soundEnabled, isTrue);
      expect(controller.value.hapticsEnabled, isFalse);
    });

    test('settings are written to the local store', () async {
      final store = MemoryGameSettingsStore();
      final controller = SettingsController(store);
      await controller.load();
      await controller.setMusicEnabled(false);
      await controller.setHapticsEnabled(false);
      expect(store.value.musicEnabled, isFalse);
      expect(store.value.hapticsEnabled, isFalse);
    });

    test('settings survive controller recreation', () async {
      final store = MemoryGameSettingsStore(
        const GameSettings(musicEnabled: false, hapticsEnabled: false),
      );
      final second = SettingsController(store);
      await second.load();
      expect(second.value.musicEnabled, isFalse);
      expect(second.value.soundEnabled, isTrue);
      expect(second.value.hapticsEnabled, isFalse);
    });

    test('disabled SFX never requests audio', () async {
      final settings = SettingsController(
        MemoryGameSettingsStore(const GameSettings(soundEnabled: false)),
      );
      await settings.load();
      final audio = FakeAudioService();
      final feedback = feedbackHarness(
        settings: settings,
        audio: audio,
        haptics: FakeHapticsService(),
      );
      feedback.handle([
        const GameFeedbackEvent(GameFeedbackType.coinCollected),
        const GameFeedbackEvent(GameFeedbackType.gameOver),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(audio.sounds, isEmpty);
    });

    test('disabled haptics never requests vibration', () async {
      final settings = SettingsController(
        MemoryGameSettingsStore(const GameSettings(hapticsEnabled: false)),
      );
      await settings.load();
      final haptics = FakeHapticsService();
      final feedback = feedbackHarness(
        settings: settings,
        audio: FakeAudioService(),
        haptics: haptics,
      );
      feedback.handle([
        const GameFeedbackEvent(GameFeedbackType.perfectLanding),
        const GameFeedbackEvent(GameFeedbackType.spikeImpact),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(haptics.cues, isEmpty);
    });

    if (_runWidgetTest('settings')) {
      testWidgets('Settings screen exposes and updates all toggles', (
        tester,
      ) async {
        final controller = SettingsController(MemoryGameSettingsStore());
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(controller: controller, onBack: () {}),
          ),
        );
        expect(find.text('Music'), findsOneWidget);
        expect(find.text('Sound Effects'), findsOneWidget);
        expect(find.text('Haptics'), findsOneWidget);
        await tester.tap(find.text('Music'));
        await tester.pump();
        expect(controller.value.musicEnabled, isFalse);
      });
    }
  });

  group('central feedback controller', () {
    test('semantic events map to sounds and haptics', () async {
      final settings = SettingsController(MemoryGameSettingsStore());
      await settings.load();
      final audio = FakeAudioService();
      final haptics = FakeHapticsService();
      final feedback = feedbackHarness(
        settings: settings,
        audio: audio,
        haptics: haptics,
      );
      feedback.handle([
        const GameFeedbackEvent(GameFeedbackType.bounce),
        const GameFeedbackEvent(GameFeedbackType.coinCollected),
        const GameFeedbackEvent(GameFeedbackType.perfectLanding),
        const GameFeedbackEvent(GameFeedbackType.nearMiss),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        audio.sounds,
        containsAll([
          SoundCue.bounce,
          SoundCue.coin,
          SoundCue.perfect,
          SoundCue.nearMiss,
        ]),
      );
      expect(haptics.cues, containsAll([HapticCue.selection, HapticCue.light]));
    });

    test('biome event requests a music transition', () async {
      final settings = SettingsController(MemoryGameSettingsStore());
      await settings.load();
      final audio = FakeAudioService();
      final feedback = feedbackHarness(
        settings: settings,
        audio: audio,
        haptics: FakeHapticsService(),
      );
      feedback.handle([
        const GameFeedbackEvent(
          GameFeedbackType.biomeChanged,
          biome: Biome.storm,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(audio.biomes, [Biome.storm]);
    });

    test('pause, resume, Game Over, restart and Home control music', () async {
      final settings = SettingsController(MemoryGameSettingsStore());
      await settings.load();
      final audio = FakeAudioService();
      final feedback = feedbackHarness(
        settings: settings,
        audio: audio,
        haptics: FakeHapticsService(),
      );
      await feedback.start();
      await feedback.pause();
      await feedback.resume();
      feedback.handle([const GameFeedbackEvent(GameFeedbackType.gameOver)]);
      await Future<void>.delayed(Duration.zero);
      await feedback.restart();
      await feedback.leaveGame();
      expect(audio.preloads, 1);
      expect(audio.pauses, greaterThanOrEqualTo(2));
      expect(audio.resumes, 1);
      expect(audio.biomes, [Biome.sunny, Biome.sunny]);
      expect(audio.stops, 1);
      expect(audio.sounds, contains(SoundCue.gameOver));
    });

    test(
      'music toggle immediately pauses and restores current biome',
      () async {
        final settings = SettingsController(MemoryGameSettingsStore());
        await settings.load();
        final audio = FakeAudioService();
        final feedback = feedbackHarness(
          settings: settings,
          audio: audio,
          haptics: FakeHapticsService(),
        );
        await feedback.start(Biome.night);
        await settings.setMusicEnabled(false);
        await Future<void>.delayed(Duration.zero);
        await settings.setMusicEnabled(true);
        await Future<void>.delayed(Duration.zero);
        expect(audio.pauses, 1);
        expect(audio.biomes, [Biome.night, Biome.night]);
      },
    );

    test('a browser-blocked start retries on the first game gesture', () async {
      final settings = SettingsController(MemoryGameSettingsStore());
      await settings.load();
      final audio = FakeAudioService()..transitionFailures = 1;
      final feedback = feedbackHarness(
        settings: settings,
        audio: audio,
        haptics: FakeHapticsService(),
      );
      await feedback.start(Biome.sunset);
      expect(audio.biomes, [Biome.sunset]);
      feedback.userGesture();
      await Future<void>.delayed(Duration.zero);
      expect(audio.biomes, [Biome.sunset, Biome.sunset]);
    });

    if (_runWidgetTest('lifecycle')) {
      testWidgets('app lifecycle pause also pauses gameplay music', (
        tester,
      ) async {
        final settings = SettingsController(MemoryGameSettingsStore());
        await settings.load();
        final audio = FakeAudioService();
        final feedback = feedbackHarness(
          settings: settings,
          audio: audio,
          haptics: FakeHapticsService(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(
              preview: true,
              feedbackFactory: () => feedback,
              onHome: () {},
            ),
          ),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(audio.pauses, greaterThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('perfect landing and streak', () {
    test('center landing is perfect', () {
      final state = GameState();
      final platform = PlatformData(100, 400);
      land(state, platform, platform.safeCenter - GameConfig.playerWidth / 2);
      final events = state.drainFeedbackEvents();
      expect(eventsOf(events, GameFeedbackType.perfectLanding), hasLength(1));
      expect(state.perfectStreak, 1);
    });

    test('edge landing is normal and resets a streak', () {
      final state = GameState()..perfectStreak = 4;
      final platform = PlatformData(100, 400);
      land(state, platform, 101);
      expect(state.phase, RunPhase.playing);
      expect(state.perfectStreak, 0);
      expect(
        eventsOf(state.drainFeedbackEvents(), GameFeedbackType.perfectLanding),
        isEmpty,
      );
    });

    test('spike platform uses the safe-region center', () {
      final state = GameState();
      final platform = PlatformData.typed(
        100,
        400,
        type: PlatformType.spike,
        spikesOnRight: true,
      );
      land(state, platform, platform.safeCenter - GameConfig.playerWidth / 2);
      expect(state.phase, RunPhase.playing);
      expect(state.perfectStreak, 1);
    });

    test('consecutive perfect landings increment and cap the streak', () {
      final state = GameState();
      final platform = PlatformData(100, 400);
      for (var index = 0; index < 14; index++) {
        land(state, platform, platform.safeCenter - GameConfig.playerWidth / 2);
        state.drainFeedbackEvents();
      }
      expect(state.perfectStreak, GameConfig.maximumPerfectStreak);
    });

    test('hazard collision resets streak', () {
      final state = GameState()..perfectStreak = 3;
      state.hazards.stormClouds.add(
        StormCloudData(x: state.x, y: state.y, minX: state.x, maxX: state.x),
      );
      state.advance(GameConfig.fixedStep);
      expect(state.perfectStreak, 0);
    });

    test('restart resets streak', () {
      final state = GameState()..perfectStreak = 6;
      state.reset();
      expect(state.perfectStreak, 0);
    });
  });

  group('near misses', () {
    test('close non-collision produces one cloud near miss', () {
      final cloud = StormCloudData(x: 100, y: 100, minX: 100, maxX: 100);
      final hazards = HazardSystem()..stormClouds.add(cloud);
      const player = WorldRect(82, 105, 10, 10);
      expect(hazards.collectNearMisses(player), 1);
      expect(hazards.collectNearMisses(player), 0);
    });

    test('actual cloud collision is not a near miss', () {
      final cloud = StormCloudData(x: 100, y: 100, minX: 100, maxX: 100);
      final hazards = HazardSystem()..stormClouds.add(cloud);
      const player = WorldRect(105, 105, 10, 10);
      expect(hazards.collideCloud(player), isNotNull);
      expect(hazards.collectNearMisses(player), 0);
    });

    test('distant pass is not a near miss', () {
      final hazards = HazardSystem()
        ..stormClouds.add(StormCloudData(x: 100, y: 100, minX: 100, maxX: 100));
      expect(hazards.collectNearMisses(const WorldRect(0, 0, 10, 10)), 0);
    });

    test('lightning near miss only occurs during strike', () {
      final bolt = LightningData(x: 100, y: 80, height: 180);
      final hazards = HazardSystem()..lightning.add(bolt);
      const player = WorldRect(84, 100, 8, 20);
      expect(hazards.collectNearMisses(player), 0);
      bolt.phase = LightningPhase.strike;
      expect(hazards.collectNearMisses(player), 1);
      expect(hazards.collectNearMisses(player), 0);
    });

    test('pause creates no false near miss and restart clears tracking', () {
      final state = GameState();
      state.hazards.stormClouds.add(
        StormCloudData(
          x: state.x + GameConfig.playerWidth + 8,
          y: state.y,
          minX: state.x + GameConfig.playerWidth + 8,
          maxX: state.x + GameConfig.playerWidth + 8,
        ),
      );
      state.pause();
      state.advance(1);
      expect(state.nearMisses, 0);
      state.reset();
      expect(state.nearMisses, 0);
      expect(state.hazards.stormClouds, isEmpty);
    });

    test('safe spike-edge landing emits one near miss', () {
      final state = GameState();
      final platform = PlatformData.typed(
        100,
        400,
        type: PlatformType.spike,
        spikesOnRight: true,
      );
      land(state, platform, platform.spikeLeft - GameConfig.playerWidth - 2);
      expect(state.phase, RunPhase.playing);
      expect(state.nearMisses, 1);
      expect(
        eventsOf(state.drainFeedbackEvents(), GameFeedbackType.nearMiss),
        hasLength(1),
      );
    });
  });

  group('personal best', () {
    test('existing best loads into run state and display', () {
      final state = GameState(personalBestScore: 1972);
      expect(state.personalBestScore, 1972);
      expect(state.displayedBestScore, 1972);
    });

    test('approach thresholds fire once each', () {
      final state = GameState(personalBestScore: 1000);
      for (final score in [900, 950, 990]) {
        climbTo(state, score);
      }
      final thresholds = eventsOf(
        state.drainFeedbackEvents(),
        GameFeedbackType.approachingBest,
      ).map((event) => event.remainingToBest);
      expect(thresholds, [100, 50, 10]);
      state.advance(GameConfig.fixedStep);
      expect(
        eventsOf(state.drainFeedbackEvents(), GameFeedbackType.approachingBest),
        isEmpty,
      );
    });

    test('NEW BEST fires exactly once after exceeding the prior best', () {
      final state = GameState(personalBestScore: 10);
      climbTo(state, 11);
      expect(
        eventsOf(state.drainFeedbackEvents(), GameFeedbackType.newPersonalBest),
        hasLength(1),
      );
      climbTo(state, 20);
      expect(
        eventsOf(state.drainFeedbackEvents(), GameFeedbackType.newPersonalBest),
        isEmpty,
      );
    });

    test('run below best never emits NEW BEST', () {
      final state = GameState(personalBestScore: 100);
      climbTo(state, 99);
      expect(state.newPersonalBest, isFalse);
    });

    test('restart resets run-specific best notifications', () {
      final state = GameState(personalBestScore: 10);
      climbTo(state, 11);
      expect(state.newPersonalBest, isTrue);
      state.reset();
      expect(state.newPersonalBest, isFalse);
      expect(state.personalBestScore, 10);
    });

    test('offline fake best uses the same deterministic logic', () {
      final state = GameState(personalBestScore: 42);
      climbTo(state, 43);
      expect(state.newPersonalBest, isTrue);
      expect(state.displayedBestScore, 43);
    });

    if (_runWidgetTest('hud')) {
      testWidgets('HUD displays injected best without credentials', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(
              preview: true,
              personalBestScore: 1972,
              onHome: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('BEST: 1972'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }

    if (_runWidgetTest('save')) {
      testWidgets(
        'failed save distinguishes a run best from server confirmation',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: GameOverOverlay(
                score: 2104,
                coins: 3,
                paused: false,
                newPersonalBest: true,
                previousBest: 1972,
                savePhase: SavePhase.failed,
                onContinue: () {},
                onHome: () {},
              ),
            ),
          );
          expect(find.text('NEW PERSONAL BEST'), findsOneWidget);
          expect(
            find.text('Run best: 2104 — server save not confirmed.'),
            findsOneWidget,
          );
          expect(find.text('Previous best: 1972'), findsOneWidget);
        },
      );
    }
  });

  group('reduced motion and bounded effects', () {
    test(
      'reduced motion lowers particle counts and disables near-miss streaks',
      () {
        expect(
          FeedbackParticleComponent.countFor(
            GameFeedbackType.newPersonalBest,
            reducedMotion: true,
          ),
          lessThan(
            FeedbackParticleComponent.countFor(
              GameFeedbackType.newPersonalBest,
              reducedMotion: false,
            ),
          ),
        );
        expect(
          FeedbackParticleComponent.countFor(
            GameFeedbackType.nearMiss,
            reducedMotion: true,
          ),
          0,
        );
      },
    );

    if (_runWidgetTest('reduced')) {
      testWidgets('reduced motion keeps text feedback understandable', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: GameScreen(preview: true, onHome: _noop),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final game = tester
            .widget<GameWidget<SkyHopperGame>>(
              find.byType(GameWidget<SkyHopperGame>),
            )
            .game!;
        final platform = PlatformData(100, 400);
        game.state
          ..platforms = [platform]
          ..x = platform.safeCenter - GameConfig.playerWidth / 2
          ..y = 359
          ..vy = 500;
        game.update(GameConfig.fixedStep);
        await tester.pump();
        expect(find.text('PERFECT!'), findsOneWidget);
        expect(game.visualMotion, isFalse);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}

void _noop() {}
