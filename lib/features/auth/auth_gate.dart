import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/widgets/sky_page.dart';
import '../home/home_screen.dart';
import '../game/widgets/game_screen.dart';
import '../game/models/game_result.dart';
import '../profile/profile_screen.dart';
import '../splash/splash_screen.dart';
import 'auth_controller.dart';
import 'login_screen.dart';
import '../leaderboard/data/leaderboard_repository.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../skins/skins_screen.dart';
import '../skins/models/skin.dart';
import '../../core/data/data_exception.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.controller,
    this.submitGameResult,
    this.loadLeaderboard,
    super.key,
  });
  final AuthController controller;
  final SubmitGameResult? submitGameResult;
  final LoadLeaderboard? loadLeaderboard;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashComplete = false;
  bool _profileOpen = false;
  bool _gameOpen = false;
  bool _leaderboardOpen = false;
  bool _skinsOpen = false;
  SkinAppearance _runAppearance = SkinAppearance.defaultSkin;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.start();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (widget.controller.stage != AuthStage.ready) {
        _profileOpen = false;
        _gameOpen = false;
        _leaderboardOpen = false;
        _skinsOpen = false;
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.controller;
    Widget screen;
    String route;
    if (!_splashComplete) {
      route = AppRoutes.splash;
      screen = SplashScreen(
        onComplete: () {
          if (mounted) setState(() => _splashComplete = true);
        },
      );
    } else if (auth.stage == AuthStage.ready) {
      route = AppRoutes.home;
      screen = HomeScreen(
        profile: auth.profile,
        onPlay: auth.profile == null
            ? null
            : () => setState(() {
                _runAppearance = auth.selectedAppearance;
                _gameOpen = true;
              }),
        onLeaderboard: auth.profile == null
            ? null
            : () => setState(() => _leaderboardOpen = true),
        onSkins: auth.profile == null
            ? null
            : () => setState(() => _skinsOpen = true),
        onProfile: auth.profile == null
            ? null
            : () => setState(() => _profileOpen = true),
      );
    } else if (auth.stage == AuthStage.signedOut ||
        auth.stage == AuthStage.unconfigured) {
      route = AppRoutes.login;
      screen = LoginScreen(controller: auth);
    } else {
      route = AppRoutes.resolve;
      final loading =
          auth.stage == AuthStage.resolving ||
          auth.stage == AuthStage.loadingProfile;
      screen = SkyPage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                auth.stage == AuthStage.loadingProfile
                    ? 'Loading your profile…'
                    : 'Restoring your session…',
              ),
            ] else ...[
              Text(
                auth.message ?? 'Unable to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: auth.stage == AuthStage.profileError
                    ? auth.retryProfile
                    : auth.retrySession,
                child: const Text('Retry'),
              ),
              if (auth.user != null)
                TextButton(
                  onPressed: auth.signingOut ? null : auth.signOut,
                  child: const Text('SIGN OUT'),
                ),
            ],
          ],
        ),
      );
    }
    // A different auth identity tears down the entire protected stack immediately.
    return Navigator(
      key: ValueKey(
        !_splashComplete
            ? 'splash'
            : '${auth.stage.name}:${auth.user?.id ?? ''}',
      ),
      pages: [
        MaterialPage(key: ValueKey(route), name: route, child: screen),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _gameOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.game),
            name: AppRoutes.game,
            child: GameScreen(
              appearance: _runAppearance,
              onHome: () => setState(() => _gameOpen = false),
              submitGameResult: _saveFor(auth.profile!.id),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _leaderboardOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.leaderboard),
            name: AppRoutes.leaderboard,
            child: LeaderboardScreen(
              load:
                  widget.loadLeaderboard ??
                  () async => throw const DataException(DataError.unavailable),
              onBack: () => setState(() => _leaderboardOpen = false),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _skinsOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.skins),
            name: AppRoutes.skins,
            child: SkinsScreen(
              auth: auth,
              onBack: () => setState(() => _skinsOpen = false),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            _profileOpen &&
            auth.profile != null)
          MaterialPage(
            key: const ValueKey(AppRoutes.profile),
            name: AppRoutes.profile,
            child: ProfileScreen(
              controller: auth,
              onBack: () => setState(() => _profileOpen = false),
            ),
          ),
      ],
      onDidRemovePage: (page) {
        if (page.name == AppRoutes.leaderboard && mounted) {
          setState(() => _leaderboardOpen = false);
        }
        if (page.name == AppRoutes.skins && mounted) {
          setState(() => _skinsOpen = false);
        }
        if (page.name == AppRoutes.game && mounted) {
          setState(() => _gameOpen = false);
        }
        if (page.name == AppRoutes.profile && mounted) {
          setState(() => _profileOpen = false);
        }
      },
    );
  }

  SubmitGameResult _saveFor(String ownerId) =>
      (result) => widget.controller.submitRunFor(
        ownerId,
        result,
        widget.submitGameResult,
      );
}
