import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/app.dart';
import 'package:sky_hopper/features/home/home_screen.dart';
import 'package:sky_hopper/features/splash/splash_screen.dart';

void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> enterHome(WidgetTester tester) async {
  await tester.pumpWidget(const SkyHopperApp(offlinePreview: true));
  expect(find.byType(SplashScreen), findsOneWidget);
  expect(find.text('SKY HOPPER'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 800));
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.byType(SplashScreen), findsNothing);
}

void main() {
  testWidgets('Splash waits two seconds, replaces route, and does not repeat', (
    tester,
  ) async {
    await tester.pumpWidget(const SkyHopperApp(offlinePreview: true));
    expect(find.text('SKY HOPPER'), findsOneWidget);
    expect(find.text('Jump beyond the clouds'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(HomeScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    expect(navigator.canPop(), isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Disposing splash cancels pending navigation', (tester) async {
    await tester.pumpWidget(const SkyHopperApp(offlinePreview: true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(280, 400),
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('Splash and Home fit $size; all menu actions work', (
      tester,
    ) async {
      setViewport(tester, size);
      await enterHome(tester);
      for (final text in [
        'SKY HOPPER',
        'PLAY',
        'LEADERBOARD',
        'SKINS',
        'PROFILE',
        'Guest Player',
        'Coins: 0',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      const messages = {
        'PLAY': 'Game mode coming in the next development step.',
        'LEADERBOARD': 'Leaderboard will be added later.',
        'SKINS': 'Skins will be added later.',
        'PROFILE': 'Profile will be added later.',
      };
      for (final entry in messages.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
        ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  }

  testWidgets('Both screens support large text in a narrow window', (
    tester,
  ) async {
    setViewport(tester, const Size(280, 400));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await enterHome(tester);
    for (final label in ['PLAY', 'LEADERBOARD', 'SKINS', 'PROFILE']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Rapid PLAY taps replace feedback without stacking routes', (
    tester,
  ) async {
    await enterHome(tester);
    await tester.ensureVisible(find.text('PLAY'));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('PLAY'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
