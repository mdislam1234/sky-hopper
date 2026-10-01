import 'dart:async';

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
import '../game/audio/game_feedback_controller.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../progression/daily_challenge_screen.dart';
import '../progression/progression_goals_screen.dart';
import '../progression/data/progression_repository.dart';
import '../progression/models/progression_snapshot.dart';
import '../ads/monetization_controller.dart';
import '../ads/rewarded_bonus_claim.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.controller,
    this.submitGameResult,
    this.loadLeaderboard,
    required this.settings,
    this.feedbackFactory,
    this.progressionRepository,
    required this.monetization,
    super.key,
  });
  final AuthController controller;
  final SubmitGameResult? submitGameResult;
  final LoadLeaderboard? loadLeaderboard;
  final SettingsController settings;
  final GameFeedbackFactory? feedbackFactory;
  final ProgressionRepository? progressionRepository;
  final MonetizationController monetization;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashComplete = false;
  bool _profileOpen = false;
  bool _gameOpen = false;
  bool _leaderboardOpen = false;
  bool _skinsOpen = false;
  bool _settingsOpen = false;
  bool _dailyChallengeOpen = false;
  bool _dailyMissionsOpen = false;
  bool _achievementsOpen = false;
  bool _openingGame = false;
  int _runBestScore = 0;
  SkinAppearance _runAppearance = SkinAppearance.defaultSkin;
  int? _runSeed;
  String? _runModeLabel;
  bool _runPreview = false;
  SubmitGameResult? _runSubmit;

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
        _settingsOpen = false;
        _dailyChallengeOpen = false;
        _dailyMissionsOpen = false;
        _achievementsOpen = false;
        _openingGame = false;
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
        playerName: auth.playerName,
        isGuest: auth.isGuest,
        onPlay: auth.profile == null ? null : () => unawaited(_openGame(auth)),
        onLeaderboard: auth.profile == null
            ? null
            : () => setState(() => _leaderboardOpen = true),
        onSkins: auth.profile == null
            ? null
            : () => setState(() => _skinsOpen = true),
        onProfile: auth.profile == null
            ? null
            : () => setState(() => _profileOpen = true),
        onSettings: () => setState(() => _settingsOpen = true),
        onDailyChallenge: widget.progressionRepository == null
            ? null
            : () => setState(() => _dailyChallengeOpen = true),
        onDailyMissions: widget.progressionRepository == null
            ? null
            : () => setState(() => _dailyMissionsOpen = true),
        onAchievements: widget.progressionRepository == null
            ? null
            : () => setState(() => _achievementsOpen = true),
      );
    } else if (auth.stage == AuthStage.unconfigured) {
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
              personalBestScore: _runBestScore,
              feedbackFactory: widget.feedbackFactory,
              seed: _runSeed,
              modeLabel: _runModeLabel,
              preview: _runPreview,
              onHome: () => setState(() {
                _gameOpen = false;
                if (_runModeLabel != null) _dailyChallengeOpen = false;
              }),
              submitGameResult: _runPreview ? null : _saveFor(auth.profile!.id),
              monetization: widget.monetization,
              rewardedEligible: !_runPreview && _runModeLabel == null,
              claimRewardedBonus: _rewardClaimFor(auth.profile!.id),
            ),
          ),
        if (_splashComplete && auth.stage == AuthStage.ready && _settingsOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.settings),
            name: AppRoutes.settings,
            child: SettingsScreen(
              controller: widget.settings,
              onBack: () => setState(() => _settingsOpen = false),
              monetization: widget.monetization,
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
              loadPeriod: widget.progressionRepository?.fetchLeaderboard,
              onBack: () => setState(() => _leaderboardOpen = false),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _dailyChallengeOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.dailyChallenge),
            name: AppRoutes.dailyChallenge,
            child: DailyChallengeScreen(
              load: widget.progressionRepository!.fetchSnapshot,
              onPlay: (snapshot, ranked) => _openDaily(auth, snapshot, ranked),
              onBack: () => setState(() => _dailyChallengeOpen = false),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _dailyMissionsOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.dailyMissions),
            name: AppRoutes.dailyMissions,
            child: ProgressionGoalsScreen(
              kind: RewardKind.mission,
              load: widget.progressionRepository!.fetchSnapshot,
              claim: widget.progressionRepository!.claimReward,
              onBalanceChanged: () =>
                  auth.refreshConfirmedProfile(auth.profile!.id),
              onBack: () => setState(() => _dailyMissionsOpen = false),
            ),
          ),
        if (_splashComplete &&
            auth.stage == AuthStage.ready &&
            auth.profile != null &&
            _achievementsOpen)
          MaterialPage(
            key: const ValueKey(AppRoutes.achievements),
            name: AppRoutes.achievements,
            child: ProgressionGoalsScreen(
              kind: RewardKind.achievement,
              load: widget.progressionRepository!.fetchSnapshot,
              claim: widget.progressionRepository!.claimReward,
              onBalanceChanged: () =>
                  auth.refreshConfirmedProfile(auth.profile!.id),
              onBack: () => setState(() => _achievementsOpen = false),
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
        if (page.name == AppRoutes.settings && mounted) {
          setState(() => _settingsOpen = false);
        }
        if (page.name == AppRoutes.dailyChallenge && mounted) {
          setState(() => _dailyChallengeOpen = false);
        }
        if (page.name == AppRoutes.dailyMissions && mounted) {
          setState(() => _dailyMissionsOpen = false);
        }
        if (page.name == AppRoutes.achievements && mounted) {
          setState(() => _achievementsOpen = false);
        }
      },
    );
  }

  SubmitGameResult _saveFor(String ownerId) =>
      (result) => widget.controller.submitRunFor(ownerId, result, _runSubmit);

  ClaimRewardedRunBonus _rewardClaimFor(String ownerId) =>
      (runId) => widget.controller.claimRewardedBonusFor(
        ownerId,
        runId,
        widget.progressionRepository?.claimRewardedRunBonus,
      );

  Future<void> _openGame(AuthController auth) async {
    if (_openingGame || auth.profile == null) return;
    setState(() => _openingGame = true);
    var bestScore = 0;
    try {
      final entries = await widget.loadLeaderboard?.call();
      if (entries != null) {
        for (final entry in entries) {
          if (entry.isCurrentUser) {
            bestScore = entry.bestScore;
            break;
          }
        }
      }
    } catch (_) {
      // A run remains playable when the one-time best-score lookup is offline.
    }
    if (!mounted || auth.stage != AuthStage.ready || auth.profile == null) {
      return;
    }
    setState(() {
      _openingGame = false;
      _runBestScore = bestScore;
      _runAppearance = auth.selectedAppearance;
      _runSeed = null;
      _runModeLabel = null;
      _runPreview = false;
      _runSubmit = widget.submitGameResult;
      _gameOpen = true;
    });
  }

  void _openDaily(
    AuthController auth,
    ProgressionSnapshot snapshot,
    bool ranked,
  ) {
    final repository = widget.progressionRepository;
    if (auth.profile == null || repository == null) return;
    setState(() {
      _runAppearance = auth.selectedAppearance;
      _runBestScore = snapshot.dailyBest;
      _runSeed = snapshot.challengeSeed;
      _runModeLabel = ranked ? 'DAILY · RANKED' : 'DAILY · PRACTICE';
      _runPreview = !ranked;
      _runSubmit = ranked
          ? (result) =>
                repository.submitDailyResult(snapshot.challengeDate, result)
          : null;
      _gameOpen = true;
    });
  }
}
