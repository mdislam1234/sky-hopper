import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/game/models/game_result.dart';
import 'features/leaderboard/data/leaderboard_repository.dart';

class SkyHopperApp extends StatefulWidget {
  const SkyHopperApp({
    this.authController,
    this.offlinePreview = false,
    this.submitGameResult,
    this.loadLeaderboard,
    super.key,
  });
  final AuthController? authController;
  final bool offlinePreview;
  final SubmitGameResult? submitGameResult;
  final LoadLeaderboard? loadLeaderboard;
  @override
  State<SkyHopperApp> createState() => _SkyHopperAppState();
}

class _SkyHopperAppState extends State<SkyHopperApp> {
  late final AuthController _auth =
      widget.authController ??
      AuthController(offlinePreview: widget.offlinePreview);

  @override
  void dispose() {
    if (widget.authController == null) _auth.dispose();
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
    ),
  );
}
