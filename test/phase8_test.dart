import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/core/widgets/app_startup.dart';
import 'package:sky_hopper/features/auth/auth_controller.dart';
import 'package:sky_hopper/features/auth/login_screen.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/components/sky_component.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/game/widgets/game_hud.dart';
import 'package:sky_hopper/features/home/home_screen.dart';
import 'package:sky_hopper/features/leaderboard/leaderboard_screen.dart';
import 'package:sky_hopper/features/leaderboard/models/leaderboard_entry.dart';
import 'package:sky_hopper/features/profile/profile_screen.dart';
import 'package:sky_hopper/features/skins/skins_screen.dart';
import 'package:sky_hopper/features/splash/splash_screen.dart';

import 'phase7_test.dart' as fixtures;

void main() {
  test(
    'PWA manifest has branded scoped standalone entries and valid PNG assets',
    () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
      expect(manifest['name'], 'Sky Hopper');
      expect(manifest['short_name'], 'Sky Hopper');
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(manifest['display'], 'standalone');
      expect(manifest['orientation'], 'portrait-primary');
      expect(manifest['theme_color'], '#75CFFF');
      expect(manifest['background_color'], '#EAF8FF');
      final icons = manifest['icons'] as List;
      expect(icons.where((icon) => icon['purpose'] == 'maskable').length, 2);
      final files = <String, int>{
        'favicon.png': 32,
        'icons/apple-touch-icon.png': 180,
      };
      for (final icon in icons) {
        files[icon['src'] as String] = int.parse(
          (icon['sizes'] as String).split('x').first,
        );
      }
      for (final entry in files.entries) {
        final bytes = File('web/${entry.key}').readAsBytesSync();
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final data = ByteData.sublistView(bytes);
        expect(data.getUint32(16), entry.value);
        expect(data.getUint32(20), entry.value);
        expect(bytes.length, lessThan(100000));
      }
    },
  );
  test(
    'Web metadata is accessible, branded and has a recoverable loading shell',
    () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<html lang="en">'));
      expect(html, contains('<title>Sky Hopper</title>'));
      expect(html, contains('name="theme-color" content="#75CFFF"'));
      expect(html, contains('aria-live="polite"'));
      expect(html, contains('prefers-reduced-motion'));
      expect(html, contains('flutter-first-frame'));
      expect(html, isNot(contains('user-scalable=no')));
      expect(html, isNot(contains('A new Flutter project')));
    },
  );
  testWidgets('Startup shows progress while initialization is pending', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(AppStartup(initialize: () => pending.future));
    expect(find.text('Getting ready…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const MaterialApp(home: Text('Ready')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });
  testWidgets(
    'Startup sanitizes errors and retries without duplicate initialization',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        AppStartup(
          initialize: () async {
            if (++calls == 1) throw StateError('private configuration token');
            return const MaterialApp(home: Text('Ready'));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private configuration'), findsNothing);
      expect(
        find.text(
          'Unable to start Sky Hopper. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(calls, 2);
    },
  );
  testWidgets('Startup completion after disposal does not navigate', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(AppStartup(initialize: () => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(const MaterialApp(home: Text('Late')));
    await tester.pump();
    expect(find.text('Late'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1280, 720),
    const Size(1440, 900),
  ]) {
    testWidgets('Major screens and Game Over fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = fixtures.Harness();
      await h.auth.start();
      final login = AuthController();
      addTearDown(login.dispose);
      await login.start();
      for (final page in <Widget>[
        SplashScreen(onComplete: () {}),
        LoginScreen(controller: login),
        HomeScreen(profile: h.auth.profile),
        ProfileScreen(controller: h.auth, onBack: () {}),
        LeaderboardScreen(
          load: () async => [LeaderboardEntry.fromJson(fixtures.boardJson())],
          onBack: () {},
        ),
        SkinsScreen(auth: h.auth, onBack: () {}),
      ]) {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: page.runtimeType.toString(),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GameScreen(preview: true, onHome: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      game.state.y = 1000;
      game.update(1 / 60);
      await tester.pump();
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('Preview — saving disabled'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Narrow large-text HUD supports long counters and accessible pause',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: GameHud(
                    score: 2147483647,
                    coins: 2147483647,
                    onPause: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Pause game'), findsOneWidget);
      final bounds = tester.getSize(find.byType(IconButton));
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    },
  );
  testWidgets(
    'Reduced motion and background lifecycle preserve pause and input clearing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: GameScreen(preview: true, onHome: () {}),
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
      expect(game.visualMotion, isFalse);
      // Opaque sky must render behind the world, never in the HUD viewport.
      expect(game.camera.backdrop, isA<SkyComponent>());
      expect(game.camera.viewport.children.whereType<SkyComponent>(), isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      expect(game.state.direction, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.state.phase, RunPhase.paused);
      expect(game.state.direction, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.state.phase, RunPhase.paused);
      await tester.tap(find.text('RESUME'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(game.state.phase, RunPhase.paused);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
