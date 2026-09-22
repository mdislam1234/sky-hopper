import 'package:flutter/material.dart';

import 'app.dart';
import 'core/data/supabase_bootstrap.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/services/auth_service.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/game/data/game_score_repository.dart';
import 'features/skins/data/skin_repository.dart';
import 'features/leaderboard/data/leaderboard_repository.dart';
import 'core/widgets/app_startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(initialize: _initializeApp));
}

Future<Widget> _initializeApp() async {
  final client = await initializeSupabase();
  final auth = client == null
      ? null
      : AuthController(
          service: SupabaseAuthService(client),
          loadProfile: ProfileRepository(client).fetchCurrent,
          skinStore: SkinRepository(client),
        );
  return SkyHopperApp(
    authController: auth,
    loadLeaderboard: client == null
        ? null
        : () => LeaderboardRepository(client).fetchLeaderboard(),
    submitGameResult: client == null
        ? null
        : GameScoreRepository(client).submitGameResult,
  );
}
