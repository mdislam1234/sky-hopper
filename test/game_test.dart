import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/auth/login_screen.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/components/player_component.dart';
import 'package:sky_hopper/features/game/components/platform_component.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/home/home_screen.dart';

import 'auth_test.dart' as auth;

void tick(GameState state, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    state.advance(GameConfig.fixedStep);
  }
}

void main() {
  test('Score begins at zero and retains maximum upward progress', () {
    final state = GameState();
    expect(state.score, 0);
    state.progress.observe(123);
    expect(state.score, 12);
    state.progress.observe(20);
    state.progress.observe(-20);
    expect(state.score, 12);
  });
  test('Game over freezes simulation and final score', () {
    final state = GameState()..y = 810;
    tick(state, 0.1);
    expect(state.phase, RunPhase.gameOver);
    final before = (state.x, state.y, state.score);
    state.direction = 1;
    tick(state, 2);
    expect((state.x, state.y, state.score), before);
  });
  test('Repeated reset clears progress, camera, input and platforms', () {
    final state = GameState();
    for (var i = 0; i < 20; i++) {
      state.progress.observe(2000);
      state.cameraTop = -1000;
      state.phase = RunPhase.gameOver;
      state.reset();
      expect(state.score, 0);
      expect(state.phase, RunPhase.playing);
      expect(state.cameraTop, 0);
      expect(state.platforms.length, 8);
      expect(state.direction, 0);
      expect(state.vy, GameConfig.jumpVelocity);
    }
  });
  test('Seeded generation stays reachable and within horizontal bounds', () {
    final generator = PlatformGenerator(Random(42));
    var previous = generator.initial().last;
    for (var i = 0; i < 10000; i++) {
      final next = generator.next(previous);
      final gap = previous.y - next.y;
      expect(
        gap,
        inInclusiveRange(GameConfig.minGap - 1e-8, GameConfig.maxGap + 1e-8),
      );
      expect(gap, lessThan(GameConfig.jumpHeight));
      expect(next.x, greaterThanOrEqualTo(0));
      expect(next.x + next.width, lessThanOrEqualTo(GameConfig.width));
      expect(
        (next.x - previous.x).abs(),
        lessThanOrEqualTo(PlatformGenerator.horizontalReach(gap) + 1e-8),
      );
      previous = next;
    }
  });
  test('Initial layout is deterministic and physically reachable', () {
    final platforms = PlatformGenerator(Random(1)).initial();
    for (var i = 1; i < platforms.length; i++) {
      final gap = platforms[i - 1].y - platforms[i].y;
      expect(gap, lessThan(GameConfig.jumpHeight));
      final state = GameState()
        ..platforms = [platforms[i - 1], platforms[i]]
        ..x = platforms[i - 1].x + platforms[i - 1].width / 2 - 16
        ..y = platforms[i - 1].y - GameConfig.playerHeight;
      final target = platforms[i].x + platforms[i].width / 2 - 16;
      for (var step = 0; step < 120 && state.bounces == 0; step++) {
        final error = target - state.x;
        state.direction = error.abs() > 10 ? error.sign.toInt() : 0;
        state.advance(GameConfig.fixedStep);
      }
      expect(state.bounces, 1);
      expect(state.y, closeTo(platforms[i].y - GameConfig.playerHeight, 0.001));
    }
  });
  test('Screen wraps only after full player leaves either edge', () {
    expect(GameState.wrap(-33), 399);
    expect(GameState.wrap(401), -31);
    expect(GameState.wrap(200), 200);
    expect(GameState.wrap(-10), -10);
  });
  for (final x in [110.0, 69.0, 199.0]) {
    test('Descending top crossing bounces at x=$x', () {
      final state = GameState()
        ..platforms = [const PlatformData(100, 400)]
        ..x = x
        ..y = 359
        ..vy = 500;
      state.advance(GameConfig.fixedStep);
      expect(state.bounces, 1);
      expect(state.vy, GameConfig.jumpVelocity);
      expect(state.y, 362);
      state.advance(GameConfig.fixedStep);
      expect(state.bounces, 1);
    });
  }
  test('Upward, underside, side, and missed contacts do not bounce', () {
    for (final values in [
      (110.0, 365.0, -500.0),
      (110.0, 405.0, 500.0),
      (205.0, 359.0, 500.0),
    ]) {
      final state = GameState()
        ..platforms = [const PlatformData(100, 400)]
        ..x = values.$1
        ..y = values.$2
        ..vy = values.$3;
      state.advance(GameConfig.fixedStep);
      expect(state.bounces, 0);
    }
  });
  test('Fast falling cannot tunnel through a top surface', () {
    final state = GameState()
      ..platforms = [const PlatformData(100, 400)]
      ..x = 110
      ..y = 300
      ..vy = 10000;
    state.advance(GameConfig.fixedStep);
    expect(state.bounces, 1);
    expect(state.y, 362);
  });
  test('Wrap does not create collisions in middle of world', () {
    final state = GameState()
      ..platforms = [const PlatformData(100, 400)]
      ..x = 399
      ..y = 359
      ..vy = 500
      ..vx = 240
      ..direction = 1;
    state.advance(GameConfig.fixedStep);
    expect(state.x, lessThan(0));
    expect(state.bounces, 0);
  });
  test('Acceleration, bounded speed, release drag and reversal', () {
    final state = GameState()..direction = 1;
    state.advance(GameConfig.fixedStep);
    expect(state.vx, inExclusiveRange(0, GameConfig.horizontalMaxSpeed));
    tick(state, 0.3);
    expect(state.vx, GameConfig.horizontalMaxSpeed);
    state.direction = -1;
    state.advance(GameConfig.fixedStep);
    expect(state.vx, greaterThan(0));
    state.direction = 0;
    tick(state, 0.3);
    expect(state.vx, 0);
  });
  test('Fixed-step trajectory is equal at 30, 60 and 120 FPS', () {
    final states = [
      for (final _ in [30, 60, 120]) GameState()..direction = 1,
    ];
    for (var i = 0; i < states.length; i++) {
      final fps = [30, 60, 120][i];
      for (var frame = 0; frame < fps * 2; frame++) {
        states[i].advance(1 / fps);
      }
    }
    for (final state in states.skip(1)) {
      expect(state.x, closeTo(states.first.x, 1e-8));
      expect(state.y, closeTo(states.first.y, 1e-8));
      expect(state.score, states.first.score);
    }
  });
  test('Pause freezes and resume continues; long frame is bounded', () {
    final state = GameState();
    state.pause();
    tick(state, 1);
    expect(state.y, 582);
    state.resume();
    state.advance(20);
    expect(state.y, greaterThan(520));
    expect(state.y, lessThan(582));
  });
  test('Camera never descends; long climbs retain bounded platform count', () {
    final state = GameState();
    var oldCamera = state.cameraTop;
    for (var i = 0; i < 2000; i++) {
      state.y = -i * 30.0;
      state.vy = -10;
      state.advance(GameConfig.fixedStep);
      expect(state.cameraTop, lessThanOrEqualTo(oldCamera));
      expect(state.platforms.length, lessThan(20));
      oldCamera = state.cameraTop;
    }
    state.y += 100;
    state.advance(GameConfig.fixedStep);
    expect(state.cameraTop, oldCamera);
  });

  for (final size in [
    const Size(360, 800),
    const Size(430, 900),
    const Size(1280, 720),
    const Size(400, 700),
  ]) {
    testWidgets('Game controls, pause and Home fit $size', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var homes = 0;
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(onHome: () => homes++)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final widget = tester.widget<GameWidget<SkyHopperGame>>(
        find.byType(GameWidget<SkyHopperGame>),
      );
      final game = widget.game!;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      expect(game.state.direction, -1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      expect(game.state.direction, 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Hold to move right')),
      );
      expect(game.state.direction, 1);
      await gesture.up();
      expect(game.state.direction, 0);
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.tap(find.text('RESUME'));
      await tester.pump();
      expect(game.state.phase, RunPhase.playing);
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      await tester.tap(find.text('HOME'));
      expect(homes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });
  }
  testWidgets('Authenticated PLAY, repeated restart, Home and auth loss', (
    tester,
  ) async {
    final service = auth.FakeAuthService()..signInEvent();
    final controller = auth.createAuth(service);
    await auth.launchApp(tester, controller);
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GameScreen), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      final game = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.world.children.whereType<PlayerComponent>().length, 1);
      expect(
        game.world.children.whereType<PlatformComponent>().length,
        lessThan(20),
      );
      game.state.y = 100;
      game.update(1 / 60);
      expect(
        game.camera.viewfinder.position.y,
        closeTo(game.state.cameraTop, 0.001),
      );
      expect(game.camera.viewfinder.position.y, lessThan(0));
      game.state.y = game.state.cameraTop + 900;
      game.update(1 / 60);
      await tester.pump();
      expect(find.text('GAME OVER'), findsOneWidget);
      await tester.tap(find.text('RESTART'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final next = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      expect(identical(next, game), isFalse);
      expect(next.state.score, 0);
      expect(game.paused, isTrue);
    }
    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Cloud Jumper'), findsOneWidget);
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await service.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
