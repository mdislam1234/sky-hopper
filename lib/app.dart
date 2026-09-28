import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/game/models/game_result.dart';
import 'features/leaderboard/data/leaderboard_repository.dart';
import 'features/game/audio/game_feedback_controller.dart';
import 'features/settings/data/game_settings_store.dart';
import 'features/settings/settings_controller.dart';
import 'features/progression/data/progression_repository.dart';

class SkyHopperApp extends StatefulWidget {
  const SkyHopperApp({
    this.authController,
    this.offlinePreview = false,
    this.submitGameResult,
    this.loadLeaderboard,
    this.settingsController,
    this.feedbackFactory,
    this.progressionRepository,
    super.key,
  });
  final AuthController? authController;
  final bool offlinePreview;
  final SubmitGameResult? submitGameResult;
  final LoadLeaderboard? loadLeaderboard;
  final SettingsController? settingsController;
  final GameFeedbackFactory? feedbackFactory;
  final ProgressionRepository? progressionRepository;
  @override
  State<SkyHopperApp> createState() => _SkyHopperAppState();
}

class _SkyHopperAppState extends State<SkyHopperApp> {
  late final AuthController _auth =
      widget.authController ??
      AuthController(offlinePreview: widget.offlinePreview);
  late final SettingsController _settings =
      widget.settingsController ??
      SettingsController(MemoryGameSettingsStore());

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    if (widget.authController == null) _auth.dispose();
    if (widget.settingsController == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sky Hopper',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    initialRoute: '/',
    home: AuthGate(
      controller: _auth,
      submitGameResult: widget.submitGameResult,
      loadLeaderboard: widget.loadLeaderboard,
      settings: _settings,
      feedbackFactory: widget.feedbackFactory,
      progressionRepository: widget.progressionRepository,
    ),
  );
}
