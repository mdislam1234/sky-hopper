import 'package:flutter/material.dart';

import 'app.dart';
import 'core/data/supabase_bootstrap.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/services/auth_service.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/skins/data/skin_repository.dart';
import 'features/leaderboard/data/leaderboard_repository.dart';
import 'features/progression/data/progression_repository.dart';
import 'core/widgets/app_startup.dart';
import 'features/game/audio/game_audio_service.dart';
import 'features/game/audio/game_feedback_controller.dart';
import 'features/game/audio/haptics_service.dart';
import 'features/settings/data/game_settings_store.dart';
import 'features/settings/settings_controller.dart';
import 'features/ads/ad_service_factory.dart';
import 'features/ads/monetization_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(initialize: _initializeApp));
}

Future<Widget> _initializeApp() async {
  final settings = SettingsController(SharedPreferencesGameSettingsStore());
  await settings.load();
  final client = await initializeSupabase();
  final auth = client == null
      ? null
      : AuthController(
          service: SupabaseAuthService(client),
          loadProfile: ProfileRepository(client).fetchCurrent,
          skinStore: SkinRepository(client),
        );
  final progression = client == null ? null : ProgressionRepository(client);
  final monetization = MonetizationController(createAdService());
  return SkyHopperApp(
    authController: auth,
    loadLeaderboard: client == null
        ? null
        : () => LeaderboardRepository(client).fetchLeaderboard(),
    submitGameResult: progression?.submitGameResult,
    progressionRepository: progression,
    monetizationController: monetization,
    settingsController: settings,
    feedbackFactory: () => GameFeedbackController(
      settings: settings,
      audio: FlameGameAudioService(),
      haptics: const SystemHapticsService(),
    ),
  );
}
