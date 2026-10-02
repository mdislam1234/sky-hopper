import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/app.dart';
import 'package:sky_hopper/features/auth/auth_controller.dart';
import 'package:sky_hopper/features/auth/login_screen.dart';
import 'package:sky_hopper/features/auth/services/auth_service.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/home/home_screen.dart';
import 'package:sky_hopper/features/profile/models/profile.dart';
import 'package:sky_hopper/features/profile/profile_screen.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.currentUser});

  @override
  AuthIdentity? currentUser;
  final events = StreamController<void>.broadcast(sync: true);
  int guestCreates = 0;
  int linkLaunches = 0;
  int signOuts = 0;
  bool guestCreateFails = false;
  bool linkLaunchFails = false;
  bool logoutFails = false;
  Completer<bool>? linkLaunch;
  Completer<void>? restoration;

  @override
  Stream<void> get changes => events.stream;

  @override
  Future<void> restoreSession() async {
    await restoration?.future;
  }

  @override
  Future<void> signInAnonymously() async {
    guestCreates++;
    if (guestCreateFails) throw Exception('private anonymous response');
    currentUser ??= const AuthIdentity(id: 'guest-user', isAnonymous: true);
    events.add(null);
  }

  @override
  Future<bool> linkGoogleIdentity() async {
    linkLaunches++;
    if (linkLaunchFails) throw Exception('private provider response');
    return linkLaunch == null ? true : await linkLaunch!.future;
  }

  void useGoogleSession({String id = 'test-user'}) {
    currentUser = AuthIdentity(
      id: id,
      email: 'player@example.test',
      displayName: 'Cloud Jumper',
    );
    events.add(null);
  }

  void signInEvent() => useGoogleSession();

  void useGuestSession({String id = 'guest-user'}) {
    currentUser = AuthIdentity(id: id, isAnonymous: true);
    events.add(null);
  }

  void completeGoogleLink() {
    final id = currentUser!.id;
    currentUser = AuthIdentity(
      id: id,
      email: 'player@example.test',
      displayName: 'Cloud Jumper',
    );
    events.add(null);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (logoutFails) throw Exception('private failure');
    currentUser = null;
    events.add(null);
  }
}

Profile profileFor(String id, {String? displayName}) => Profile(
  id: id,
  displayName: displayName,
  totalCoins: 42,
  selectedSkin: 'default',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final testProfile = profileFor('test-user', displayName: 'Cloud Jumper');

AuthController createAuth(
  FakeAuthService service, {
  Future<Profile?> Function()? loader,
}) {
  final controller = AuthController(
    service: service,
    loadProfile:
        loader ??
        () async {
          final identity = service.currentUser!;
          return profileFor(
            identity.id,
            displayName: identity.isAnonymous ? null : 'Cloud Jumper',
          );
        },
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
      'com.azitechstudio.skyhopper://login-callback/',
    );
  });

  testWidgets('First launch creates one guest session and reaches Home', (
    tester,
  ) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    expect(service.guestCreates, 1);
    expect(auth.user?.id, 'guest-user');
    expect(auth.isGuest, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Guest Player'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Existing Google session is preserved without guest creation', (
    tester,
  ) async {
    final service = FakeAuthService()..useGoogleSession();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    expect(service.guestCreates, 0);
    expect(auth.user?.id, 'test-user');
    expect(auth.isGuest, isFalse);
    expect(find.text('Cloud Jumper'), findsOneWidget);
  });

  testWidgets('Existing anonymous session is preserved without duplication', (
    tester,
  ) async {
    final service = FakeAuthService()..useGuestSession(id: 'saved-guest');
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await auth.start();
    expect(service.guestCreates, 0);
    expect(auth.user?.id, 'saved-guest');
    expect(find.text('Guest Player'), findsOneWidget);
  });

  testWidgets('Unconfigured startup reports unavailable services, not login', (
    tester,
  ) async {
    await tester.pumpWidget(const SkyHopperApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Game services are unavailable'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Guest can open Profile and start normal gameplay', (
    tester,
  ) async {
    final auth = createAuth(FakeAuthService());
    await launchApp(tester, auth);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Playing as Guest'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('Google linking keeps the guest owner and confirmed balance', (
    tester,
  ) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    final guestId = auth.user!.id;
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    expect(service.linkLaunches, 1);
    expect(auth.signingIn, isTrue);
    service.completeGoogleLink();
    await tester.pumpAndSettle();
    expect(auth.user?.id, guestId);
    expect(auth.isGuest, isFalse);
    expect(auth.profile?.totalCoins, 42);
    expect(find.text('Cloud Jumper'), findsOneWidget);
  });

  testWidgets('Rapid link taps launch Google only once', (tester) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Sign in with Google'));
    }
    await tester.pump();
    expect(service.linkLaunches, 1);
    auth.cancelPendingSignIn();
    await tester.pump();
  });

  testWidgets('Link launch failure is sanitized and allows retry', (
    tester,
  ) async {
    final service = FakeAuthService()..linkLaunchFails = true;
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(
      find.text('Google sign-in could not open. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private provider'), findsNothing);
    expect(auth.signingIn, isFalse);
  });

  testWidgets('OAuth cancel restores the optional link action', (tester) async {
    final auth = createAuth(FakeAuthService());
    await launchApp(tester, auth);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cancel sign-in'));
    await tester.tap(find.text('Cancel sign-in'));
    await tester.pumpAndSettle();
    expect(auth.signingIn, isFalse);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('Signing out a permanent user immediately creates a guest', (
    tester,
  ) async {
    final service = FakeAuthService()..useGoogleSession();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();
    expect(service.signOuts, 1);
    expect(service.guestCreates, 1);
    expect(auth.isGuest, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Guest Player'), findsOneWidget);
  });

  testWidgets('Guest creation failure leaves a retryable screen', (
    tester,
  ) async {
    final service = FakeAuthService()..guestCreateFails = true;
    final auth = createAuth(service);
    await launchApp(tester, auth);
    expect(auth.stage, AuthStage.sessionError);
    expect(find.textContaining('Guest play could not start'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Missing profile shows retry instead of fabricating a row', (
    tester,
  ) async {
    final service = FakeAuthService();
    var found = false;
    final auth = createAuth(
      service,
      loader: () async => found ? profileFor('guest-user') : null,
    );
    await launchApp(tester, auth);
    expect(
      find.textContaining('player profile is not available'),
      findsOneWidget,
    );
    found = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Late profile response after account change stays isolated', (
    tester,
  ) async {
    final service = FakeAuthService()..useGoogleSession();
    final pending = Completer<Profile?>();
    final auth = createAuth(service, loader: () => pending.future);
    await tester.pumpWidget(SkyHopperApp(authController: auth));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Loading your profile…'), findsOneWidget);
    service.useGuestSession(id: 'other-owner');
    pending.complete(profileFor('test-user', displayName: 'Cloud Jumper'));
    await tester.pumpAndSettle();
    expect(auth.user?.id, 'other-owner');
    expect(auth.profile?.id, isNot('test-user'));
  });

  testWidgets(
    'Session restoration preserves a session that arrives in flight',
    (tester) async {
      final service = FakeAuthService()..restoration = Completer<void>();
      final auth = createAuth(service);
      await tester.pumpWidget(SkyHopperApp(authController: auth));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Restoring your session…'), findsOneWidget);
      service.useGoogleSession();
      service.restoration!.complete();
      await tester.pumpAndSettle();
      expect(service.guestCreates, 0);
      expect(auth.user?.id, 'test-user');
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('Auth stream failure shows safe recoverable feedback', (
    tester,
  ) async {
    final service = FakeAuthService();
    final auth = createAuth(service);
    await launchApp(tester, auth);
    service.events.addError(Exception('private token'));
    await tester.pumpAndSettle();
    expect(
      auth.message,
      'Account connection was interrupted. Please try again.',
    );
    expect(auth.message, isNot(contains('private token')));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  for (final size in [
    const Size(280, 400),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('Guest Home and Profile fit $size with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = createAuth(FakeAuthService());
      await launchApp(tester, auth);
      expect(find.byKey(const ValueKey('home-action-grid')), findsOneWidget);
      await tester.ensureVisible(find.text('Profile'));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in with Google'));
      expect(tester.takeException(), isNull);
    });
  }
}
