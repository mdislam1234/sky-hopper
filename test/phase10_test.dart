import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/coin_system.dart';
import 'package:sky_hopper/features/game/systems/difficulty_director.dart';
import 'package:sky_hopper/features/game/systems/environment_system.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/systems/hazard_system.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';

void tick(GameState state, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    state.advance(GameConfig.fixedStep);
  }
}

PlatformData typedPlatform(
  PlatformType type, {
  double x = 100,
  double y = 400,
  double travel = 0,
  double speed = 0,
  bool spikesOnRight = true,
}) => PlatformData.typed(
  x,
  y,
  type: type,
  movementTravel: travel,
  movementSpeed: speed,
  spikesOnRight: spikesOnRight,
);

void main() {
  group('biomes', () {
    test('score zero is Sunny and final high score is Space', () {
      expect(BiomeSystem.forScore(0), Biome.sunny);
      expect(BiomeSystem.forScore(399), Biome.sunny);
      expect(BiomeSystem.forScore(1900), Biome.space);
      expect(BiomeSystem.forScore(100000), Biome.space);
    });

    test('all configured thresholds select the expected biome', () {
      expect(BiomeSystem.forScore(400), Biome.sunset);
      expect(BiomeSystem.forScore(799), Biome.sunset);
      expect(BiomeSystem.forScore(800), Biome.storm);
      expect(BiomeSystem.forScore(1299), Biome.storm);
      expect(BiomeSystem.forScore(1300), Biome.night);
      expect(BiomeSystem.forScore(1899), Biome.night);
    });

    test('transition bands blend gradually around each threshold', () {
      for (final threshold in [400, 800, 1300, 1900]) {
        expect(BiomeSystem.frameForScore(threshold - 50).blend, 0);
        expect(BiomeSystem.frameForScore(threshold).blend, closeTo(0.5, 1e-9));
        expect(BiomeSystem.frameForScore(threshold + 50).blend, 1);
      }
    });

    test('environment changes do not alter score or player state', () {
      final state = GameState()
        ..x = 37
        ..y = 211
        ..vx = 42
        ..vy = -123;
      final before = (state.x, state.y, state.vx, state.vy);
      state.environment.update(1400);
      expect((state.x, state.y, state.vx, state.vy), before);
      expect(state.score, 0);
      expect(state.environment.biome, Biome.night);
    });

    test('restart returns biome, score and cause to their defaults', () {
      final state = GameState();
      state.progress.observe(20000);
      state.environment.update(state.score);
      state.gameOverCause = GameOverCause.lightning;
      expect(state.environment.biome, Biome.space);
      state.reset();
      expect(state.environment.biome, Biome.sunny);
      expect(state.score, 0);
      expect(state.gameOverCause, isNull);
    });

    test('visual configuration exists for every biome', () {
      expect(BiomeSystem.visuals.keys.toSet(), Biome.values.toSet());
      for (final visual in BiomeSystem.visuals.values) {
        expect(visual.starDensity, inInclusiveRange(0, 1));
        expect(visual.rainDensity, inInclusiveRange(0, 1));
      }
    });
  });

  group('moving platforms', () {
    test('motion remains bounded and reverses at both edges', () {
      final platform = typedPlatform(
        PlatformType.moving,
        travel: 10,
        speed: 20,
      );
      platform.advance(0.5);
      expect(platform.x, platform.movementMaxX);
      platform.advance(0.1);
      expect(platform.movementDirection, -1);
      expect(platform.x, lessThan(platform.movementMaxX));
      platform.advance(1);
      expect(
        platform.x,
        inInclusiveRange(platform.movementMinX, platform.movementMaxX),
      );
      expect(platform.movementDirection, 1);
    });

    test('pause freezes platform motion', () {
      final platform = typedPlatform(
        PlatformType.moving,
        travel: 20,
        speed: 30,
      );
      final state = GameState()..platforms = [platform];
      state.pause();
      tick(state, 2);
      expect(platform.x, platform.originX);
    });

    test('player bounces normally on moving platform', () {
      final platform = typedPlatform(
        PlatformType.moving,
        travel: 10,
        speed: 10,
      );
      final state = GameState()
        ..platforms = [platform]
        ..x = 110
        ..y = 359
        ..vy = 500;
      state.advance(GameConfig.fixedStep);
      expect(state.bounces, 1);
      expect(state.vy, GameConfig.jumpVelocity);
    });

    test('restart discards prior moving-platform state', () {
      final old = typedPlatform(PlatformType.moving, travel: 20, speed: 30);
      final state = GameState()..platforms = [old];
      state.advance(0.2);
      expect(old.x, isNot(old.originX));
      state.reset();
      expect(state.platforms, isNot(contains(old)));
      expect(
        state.platforms.every(
          (platform) => platform.type == PlatformType.normal,
        ),
        isTrue,
      );
    });
  });

  group('crumbling platforms', () {
    test('untouched platform remains stable', () {
      final platform = typedPlatform(PlatformType.crumbling);
      platform.advance(10);
      expect(platform.crumbleActivated, isFalse);
      expect(platform.collidable, isTrue);
    });

    test('landing activates a delayed, one-time collapse', () {
      final platform = typedPlatform(PlatformType.crumbling);
      platform.onLanded();
      expect(platform.crumbleActivated, isTrue);
      platform.advance(GameConfig.crumbleDelay - 0.01);
      expect(platform.collidable, isTrue);
      platform.advance(0.02);
      expect(platform.collidable, isFalse);
      expect(platform.collapseCount, 1);
      platform.onLanded();
      platform.advance(10);
      expect(platform.collapseCount, 1);
    });

    test('a real landing starts the crumble timer', () {
      final platform = typedPlatform(PlatformType.crumbling);
      final state = GameState()
        ..platforms = [platform]
        ..x = 110
        ..y = 359
        ..vy = 500;
      state.advance(GameConfig.fixedStep);
      expect(platform.crumbleActivated, isTrue);
      expect(state.bounces, 1);
    });

    test('pause freezes an active crumble timer', () {
      final platform = typedPlatform(PlatformType.crumbling)..onLanded();
      final state = GameState()..platforms = [platform];
      state.pause();
      tick(state, 2);
      expect(platform.crumbleElapsed, 0);
      expect(platform.collidable, isTrue);
    });
  });

  group('spike platforms', () {
    test('visible spike geometry exposes the exact lethal region', () {
      final platform = typedPlatform(PlatformType.spike);
      expect(
        platform.spikeLeft,
        platform.x + platform.width - platform.spikeWidth,
      );
      expect(platform.spikeRight, platform.x + platform.width);
      expect(
        platform.safeWidth,
        greaterThanOrEqualTo(GameConfig.minimumSafeLandingWidth),
      );
      expect(
        platform.overlapsSpikes(platform.spikeLeft + 1, platform.spikeRight),
        isTrue,
      );
      expect(
        platform.overlapsSpikes(platform.safeLeft, platform.spikeLeft),
        isFalse,
      );
    });

    test('landing on the safe section still bounces', () {
      final state = GameState()
        ..platforms = [typedPlatform(PlatformType.spike)]
        ..x = 108
        ..y = 359
        ..vy = 500;
      state.advance(GameConfig.fixedStep);
      expect(state.phase, RunPhase.playing);
      expect(state.bounces, 1);
      expect(state.gameOverCause, isNull);
    });

    test(
      'spike contact causes Game Over without false full-platform death',
      () {
        final state = GameState()
          ..platforms = [typedPlatform(PlatformType.spike)]
          ..x = 176
          ..y = 359
          ..vy = 500;
        state.advance(GameConfig.fixedStep);
        expect(state.phase, RunPhase.gameOver);
        expect(state.gameOverCause, GameOverCause.spikes);
        expect(state.bounces, 0);
      },
    );
  });

  group('wind', () {
    WindZoneData zone() => WindZoneData(
      x: 0,
      y: 0,
      width: 120,
      height: 300,
      direction: 1,
      acceleration: GameConfig.windMinAcceleration,
    );

    test('wind applies force only inside its visible bounds', () {
      final system = HazardSystem()..windZones.add(zone());
      expect(
        system.windAccelerationAt(const WorldRect(20, 20, 32, 38)),
        greaterThan(0),
      );
      expect(system.windAccelerationAt(const WorldRect(200, 20, 32, 38)), 0);
    });

    test('steering remains stronger than introductory wind', () {
      final state = GameState()
        ..x = 20
        ..y = 40
        ..direction = -1;
      state.hazards.windZones.add(zone());
      state.advance(GameConfig.fixedStep);
      expect(state.vx, lessThan(0));
      expect(
        GameConfig.horizontalAcceleration,
        greaterThan(GameConfig.windMinAcceleration),
      );
    });

    test('pause freezes wind animation and restart clears wind', () {
      final state = GameState();
      final gust = zone();
      state.hazards.windZones.add(gust);
      state.pause();
      tick(state, 1);
      expect(gust.animationTime, 0);
      state.reset();
      expect(state.hazards.windZones, isEmpty);
    });
  });

  group('storm clouds', () {
    test('cloud patrol stays bounded and reverses', () {
      final cloud = StormCloudData(x: 10, y: 50, minX: 10, maxX: 30, speed: 20);
      cloud.advance(1);
      expect(cloud.x, 30);
      cloud.advance(0.2);
      expect(cloud.direction, -1);
      expect(cloud.x, inInclusiveRange(10, 30));
    });

    test('collision applies once per cooldown and remains recoverable', () {
      final cloud = StormCloudData(x: 10, y: 50, minX: 10, maxX: 30);
      final system = HazardSystem()..stormClouds.add(cloud);
      const player = WorldRect(20, 55, 32, 38);
      final first = system.collideCloud(player);
      expect(first, isNotNull);
      expect(first!.verticalVelocity, lessThan(-GameConfig.jumpVelocity));
      expect(system.collideCloud(player), isNull);
      system.advance(GameConfig.stormCloudCollisionCooldown + 0.01);
      expect(system.collideCloud(player), isNotNull);
    });

    test('pause freezes cloud and cleanup removes old cloud', () {
      final state = GameState();
      final cloud = StormCloudData(x: 10, y: 50, minX: 10, maxX: 30);
      state.hazards.stormClouds.add(cloud);
      state.pause();
      tick(state, 1);
      expect(cloud.x, 10);
      state.hazards.cleanup(-1000);
      expect(state.hazards.stormClouds, isEmpty);
    });
  });

  group('lightning', () {
    test('warning is nonlethal, strike is lethal, and expiry is safe', () {
      final bolt = LightningData(x: 10, y: 10, height: 200);
      final system = HazardSystem()..lightning.add(bolt);
      const player = WorldRect(12, 20, 20, 30);
      expect(bolt.phase, LightningPhase.warning);
      expect(system.lightningHits(player), isFalse);
      bolt.advance(GameConfig.lightningWarningDuration);
      expect(bolt.phase, LightningPhase.strike);
      expect(system.lightningHits(player), isTrue);
      bolt.advance(GameConfig.lightningStrikeDuration);
      expect(bolt.phase, LightningPhase.clear);
      expect(system.lightningHits(player), isFalse);
      bolt.advance(GameConfig.lightningClearDuration);
      expect(bolt.phase, LightningPhase.expired);
      expect(system.lightningHits(player), isFalse);
    });

    test('strike collision records the lightning Game Over cause', () {
      final state = GameState();
      final bolt = LightningData(x: state.x, y: state.y - 20, height: 120)
        ..phase = LightningPhase.strike;
      state.hazards.lightning.add(bolt);
      state.advance(GameConfig.fixedStep);
      expect(state.phase, RunPhase.gameOver);
      expect(state.gameOverCause, GameOverCause.lightning);
    });

    test('pause freezes the warning timer', () {
      final state = GameState();
      final bolt = LightningData(x: 0, y: 0, height: 100);
      state.hazards.lightning.add(bolt);
      state.pause();
      tick(state, 2);
      expect(bolt.phase, LightningPhase.warning);
      expect(bolt.phaseElapsed, 0);
    });
  });

  group('difficulty and fair generation', () {
    test('representative scores unlock hazards progressively', () {
      final low = DifficultyDirector.forScore(0);
      final mid = DifficultyDirector.forScore(900);
      final high = DifficultyDirector.forScore(2000);
      expect(low.probabilities.every((value) => value == 0), isTrue);
      expect(mid.movingChance, greaterThan(0));
      expect(mid.windChance, greaterThan(0));
      expect(mid.stormCloudChance, greaterThan(0));
      expect(mid.spikeChance, 0);
      expect(mid.lightningChance, 0);
      expect(high.probabilities.every((value) => value > 0), isTrue);
    });

    test('all probability and force values remain bounded', () {
      for (final score in [0, 250, 500, 800, 1100, 1400, 1800, 100000]) {
        final profile = DifficultyDirector.forScore(score);
        for (final chance in profile.probabilities) {
          expect(chance, inInclusiveRange(0, 1));
        }
        expect(
          profile.movingSpeed,
          inInclusiveRange(
            GameConfig.movingPlatformMinSpeed,
            GameConfig.movingPlatformMaxSpeed,
          ),
        );
        expect(
          profile.windAcceleration,
          lessThan(GameConfig.horizontalAcceleration),
        );
      }
    });

    test('seeded platform type, position and coin choices reproduce', () {
      List<String> build() {
        final generator = PlatformGenerator(Random(314));
        final coins = CoinSystem();
        var platform = generator.initial().last;
        return List.generate(80, (_) {
          platform = generator.next(platform, score: 2200);
          final before = coins.coins.length;
          coins.addPlatform(platform);
          final placed = coins.coins
              .skip(before)
              .map((coin) => '${coin.x}:${coin.y}')
              .join(',');
          return '${platform.x}|${platform.y}|${platform.type.name}|$placed';
        });
      }

      expect(build(), build());
    });

    test('generated routes retain safe landings and recovery platforms', () {
      final generator = PlatformGenerator(Random(42));
      var previous = generator.initial().last;
      var priorWasRisky = false;
      var riskyCount = 0;
      for (var i = 0; i < 2000; i++) {
        final next = generator.next(previous, score: 5000);
        final gap = previous.y - next.y;
        expect(
          next.safeWidth,
          greaterThanOrEqualTo(GameConfig.minimumSafeLandingWidth),
        );
        expect(gap, lessThan(GameConfig.jumpHeight));
        expect(
          next.movementMinX,
          greaterThanOrEqualTo(GameConfig.platformMargin),
        );
        expect(
          next.movementMaxX + next.width,
          lessThanOrEqualTo(GameConfig.width - GameConfig.platformMargin),
        );
        if (priorWasRisky) expect(next.type, PlatformType.normal);
        priorWasRisky = next.isRisky;
        if (next.isRisky) riskyCount++;
        previous = next;
      }
      expect(riskyCount, greaterThan(0));
    });

    test('airborne hazards never stack and leave a recovery segment', () {
      final hazards = HazardSystem(random: Random(99));
      final profile = DifficultyDirector.forScore(5000);
      var lower = PlatformData(100, 400);
      var observed = 0;
      for (var i = 0; i < 200; i++) {
        final upper = PlatformData(180, lower.y - 85);
        final before =
            hazards.windZones.length +
            hazards.stormClouds.length +
            hazards.lightning.length;
        hazards.addBetween(lower, upper, profile);
        final after =
            hazards.windZones.length +
            hazards.stormClouds.length +
            hazards.lightning.length;
        expect(after - before, inInclusiveRange(0, 1));
        if (after > before) {
          observed++;
          final recovery = PlatformData(120, upper.y - 85);
          final recoveryBefore = after;
          hazards.addBetween(upper, recovery, profile);
          expect(
            hazards.windZones.length +
                hazards.stormClouds.length +
                hazards.lightning.length,
            recoveryBefore,
          );
          lower = recovery;
        } else {
          lower = upper;
        }
      }
      expect(observed, greaterThan(0));
    });

    test('riskier platforms add at most one optional bonus coin', () {
      final coins = CoinSystem();
      final normal = PlatformData(100, 400);
      final moving = typedPlatform(
        PlatformType.moving,
        y: 300,
        travel: 20,
        speed: 30,
      );
      final spike = typedPlatform(PlatformType.spike, y: 200);
      coins.addPlatform(normal);
      final afterNormal = coins.coins.length;
      coins.addPlatform(moving);
      final movingAdded = coins.coins.length - afterNormal;
      final beforeSpike = coins.coins.length;
      coins.addPlatform(spike);
      final spikeAdded = coins.coins.length - beforeSpike;
      expect(afterNormal, 1);
      expect(movingAdded, 1);
      expect(spikeAdded, 1);
      CoinData? spikeBonus;
      for (var i = 0; i < 4; i++) {
        final candidate = typedPlatform(PlatformType.spike, y: 100 - i * 80);
        final before = coins.coins.length;
        coins.addPlatform(candidate);
        final added = coins.coins.skip(before).toList();
        expect(added.length, lessThanOrEqualTo(2));
        for (final coin in added) {
          if (coin.x >= candidate.spikeLeft && coin.x <= candidate.spikeRight) {
            spikeBonus = coin;
          }
        }
      }
      expect(spikeBonus, isNotNull);
    });

    test('procedural state remains bounded during a long high climb', () {
      final state = GameState();
      for (var i = 0; i < 1500; i++) {
        state.progress.observe(22000);
        state.y = -i * 30.0;
        state.vy = -10;
        state.advance(GameConfig.fixedStep);
        final hazardCount =
            state.hazards.windZones.length +
            state.hazards.stormClouds.length +
            state.hazards.lightning.length;
        expect(state.platforms.length, lessThan(20));
        expect(state.coinSystem.coins.length, lessThan(20));
        expect(hazardCount, lessThan(20));
      }
    });
  });

  testWidgets('GameScreen shows and clears a transient biome notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(preview: true, onHome: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<SkyHopperGame>>(
          find.byType(GameWidget<SkyHopperGame>),
        )
        .game!;
    game.state.progress.observe(GameConfig.sunsetScore * GameConfig.scoreScale);
    game.state.environment.update(game.state.score);
    game.update(GameConfig.fixedStep);
    await tester.pump();
    expect(find.text('ENTERING SUNSET'), findsOneWidget);
    game.update(GameConfig.biomeNoticeDuration + 0.1);
    await tester.pump();
    expect(find.text('ENTERING SUNSET'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'spike Game Over uses the shared result overlay and safe wording',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(preview: true, onHome: () {})),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      game.state
        ..platforms = [typedPlatform(PlatformType.spike)]
        ..x = 176
        ..y = 359
        ..vy = 500;
      game.update(GameConfig.fixedStep);
      await tester.pump();
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('Hit the spikes!'), findsOneWidget);
      expect(find.text('Preview — saving disabled'), findsOneWidget);
      await tester.tap(find.text('RESTART'));
      await tester.pump();
      final restarted = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      expect(restarted.state.environment.biome, Biome.sunny);
      expect(restarted.state.gameOverCause, isNull);
      expect(restarted.state.hazards.lightning, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1280, 720),
  ]) {
    testWidgets('Phase 10 world renders without overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(preview: true, onHome: () {})),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      game.state.progress.observe(20000);
      game.state.environment.update(game.state.score);
      game.state.platforms.addAll([
        typedPlatform(PlatformType.moving, y: 260, travel: 20, speed: 30),
        typedPlatform(PlatformType.crumbling, x: 220, y: 180),
        typedPlatform(PlatformType.spike, x: 30, y: 100),
      ]);
      game.state.hazards.windZones.add(
        WindZoneData(
          x: 0,
          y: 120,
          width: 104,
          height: 180,
          direction: 1,
          acceleration: 220,
        ),
      );
      game.state.hazards.stormClouds.add(
        StormCloudData(x: 220, y: 240, minX: 200, maxX: 300),
      );
      game.state.hazards.lightning.add(
        LightningData(x: 330, y: 40, height: 260),
      );
      game.update(GameConfig.fixedStep);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
