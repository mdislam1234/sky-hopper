import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/app.dart';
import 'package:sky_hopper/features/auth/auth_controller.dart';
import 'package:sky_hopper/features/auth/login_screen.dart';
import 'package:sky_hopper/features/auth/services/auth_service.dart';
import 'package:sky_hopper/features/home/home_screen.dart';
import 'package:sky_hopper/features/profile/models/profile.dart';
import 'package:sky_hopper/features/profile/profile_screen.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.currentUser});
  @override
  AuthIdentity? currentUser;
  final events = StreamController<void>.broadcast(sync: true);
  int launches = 0;
  bool launchFails = false;
  bool logoutFails = false;
  Completer<bool>? launch;
  Completer<void>? restoration;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<void> restoreSession() async {
    await restoration?.future;
  }

  @override
  Future<bool> signInWithGoogle() async {
    launches++;
    if (launchFails) throw Exception('private provider response');
    return launch == null ? true : await launch!.future;
  }

  void signInEvent() {
    currentUser = const AuthIdentity(
      id: 'test-user',
      email: 'player@example.test',
    );
    events.add(null);
  }

  @override
  Future<void> signOut() async {
    if (logoutFails) throw Exception('private failure');
    currentUser = null;
    events.add(null);
  }
}

final testProfile = Profile(
  id: 'test-user',
  displayName: 'Cloud Jumper',
  totalCoins: 42,
  selectedSkin: 'default',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

AuthController createAuth(
  FakeAuthService service, {
  Future<Profile?> Function()? loader,
}) {
  final controller = AuthController(
    service: service,
    loadProfile: loader ?? () async => testProfile,
  );
  addTearDown(controller.dispose);
  addTearDown(service.events.close);
  return controller;
}

Future<void> launchApp(WidgetTester tester, AuthController auth) async {
  await tester.pumpWidget(SkyHopperApp(authController: auth));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  test('Redirects use runtime web origin or exact Android callback', () {
    expect(
      oauthRedirect(
        isWeb: true,
        base: Uri.parse('https://game.example/path?code=unused#/home'),
      ),
      'https://game.example/',
    );
    expect(
      oauthRedirect(isWeb: true, base: Uri.parse('http://localhost:3000/')),
      'http://localhost:3000/',
    );
    expect(
      oauthRedirect(isWeb: false, base: Uri.parse('file:///app')),
      'com.skyhopper.game://login-callback/',
    );
  });

  testWidgets('Signed-out startup shows Google Login, never Home', (
    tester,
  ) async {
    final auth = createAuth(FakeAuthService());
    await launchApp(tester, auth);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Unconfigured startup visibly disables authentication', (
    tester,
  ) async {
    await tester.pumpWidget(const SkyHopperApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sign-in is currently unavailable'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
    'Signed-in startup loads real profile presentation and Profile route',
    (tester) async {
      final service = FakeAuthService()..signInEvent();
      final auth = createAuth(service);
      await launchApp(tester, auth);
      expect(find.text('Cloud Jumper'), findsOneWidget);
      expect(find.text('Coins: 42'), findsOneWidget);
      await tester.ensureVisible(find.text('PROFILE'));
      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('player@example.test'), findsOneWidget);
      expect(find.text('Selected skin: default'), findsOneWidget);
    },
  );

  testWidgets('Rapid taps start only one OAuth launch; event reaches Home', (
    tester,
  ) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Continue with Google'));
    }
    await tester.pump();
    expect(service.launches, 1);
    expect(auth.signingIn, isTrue);
    service.signInEvent();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Launch failure is sanitized and allows retry', (tester) async {
    final service = FakeAuthService()..launchFails = true;
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(
      find.text('Google sign-in could not open. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private provider'), findsNothing);
    expect(auth.signingIn, isFalse);
  });

  testWidgets('OAuth cancel restores the button', (tester) async {
    final auth = createAuth(FakeAuthService());
    await launchApp(tester, auth);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cancel sign-in'));
    await tester.tap(find.text('Cancel sign-in'));
    await tester.pumpAndSettle();
    expect(auth.signingIn, isFalse);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Logout clears protected data and back cannot reveal it', (
    tester,
  ) async {
    final service = FakeAuthService()..signInEvent();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await tester.ensureVisible(find.text('PROFILE'));
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SIGN OUT'));
    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.profile, isNull);
    expect(auth.user, isNull);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);
    final navigator = Navigator.of(tester.element(find.byType(LoginScreen)));
    expect(await navigator.maybePop(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Cloud Jumper'), findsNothing);
  });

  testWidgets('Missing profile shows retry instead of fabricating a row', (
    tester,
  ) async {
    final service = FakeAuthService()..signInEvent();
    var found = false;
    final auth = createAuth(
      service,
      loader: () async => found ? testProfile : null,
    );
    await launchApp(tester, auth);
    expect(
      find.textContaining('Your profile is not available'),
      findsOneWidget,
    );
    found = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'Late profile response after sign-out cannot restore protected state',
    (tester) async {
      final service = FakeAuthService()..signInEvent();
      final pending = Completer<Profile?>();
      final auth = createAuth(service, loader: () => pending.future);
      await tester.pumpWidget(SkyHopperApp(authController: auth));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Loading your profile…'), findsOneWidget);
      await service.signOut();
      pending.complete(testProfile);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.profile, isNull);
    },
  );

  testWidgets('Session restoration waits before showing a destination', (
    tester,
  ) async {
    final service = FakeAuthService()..restoration = Completer<void>();
    final auth = createAuth(service);
    await tester.pumpWidget(SkyHopperApp(authController: auth));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Restoring your session…'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    service.signInEvent();
    service.restoration!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Auth stream failure and logout failure show safe feedback', (
    tester,
  ) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    service.events.addError(Exception('private token'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sign-in could not be completed'),
      findsOneWidget,
    );
    service.signInEvent();
    await tester.pumpAndSettle();
    service.logoutFails = true;
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(auth.stage, AuthStage.ready);
    expect(
      auth.message,
      'Sign out failed. Please check your connection and retry.',
    );
    expect(auth.message, isNot(contains('private')));
  });

  for (final size in [
    const Size(280, 400),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('Login and Profile fit $size with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = FakeAuthService();
      final auth = createAuth(service);
      await launchApp(tester, auth);
      expect(tester.takeException(), isNull);
      service.signInEvent();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('PROFILE'));
      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SIGN OUT'));
      expect(tester.takeException(), isNull);
    });
  }
}
