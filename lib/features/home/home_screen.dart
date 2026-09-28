import 'package:flutter/material.dart';

import '../../core/widgets/game_menu_button.dart';
import '../../core/widgets/sky_hopper_logo.dart';
import '../../core/widgets/sky_page.dart';
import 'widgets/player_summary_card.dart';
import '../profile/models/profile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    this.profile,
    this.onProfile,
    this.onPlay,
    this.onLeaderboard,
    this.onDailyChallenge,
    this.onDailyMissions,
    this.onAchievements,
    this.onSkins,
    this.onSettings,
    super.key,
  });
  final Profile? profile;
  final VoidCallback? onProfile;
  final VoidCallback? onPlay;
  final VoidCallback? onLeaderboard;
  final VoidCallback? onDailyChallenge;
  final VoidCallback? onDailyMissions;
  final VoidCallback? onAchievements;
  final VoidCallback? onSkins;
  final VoidCallback? onSettings;

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkyHopperLogo(),
          const SizedBox(height: 12),
          Text(
            'Jump higher. Collect coins. Beat your best.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          PlayerSummaryCard(
            playerName: profile == null
                ? 'Guest Player'
                : (profile!.displayName?.trim().isNotEmpty ?? false)
                ? profile!.displayName!
                : 'Player',
            coins: profile?.totalCoins ?? 0,
          ),
          const SizedBox(height: 24),
          GameMenuButton(
            label: 'PLAY',
            icon: Icons.play_arrow_rounded,
            primary: true,
            onPressed:
                onPlay ??
                () => _showMessage(
                  context,
                  'Game mode coming in the next development step.',
                ),
          ),
          const SizedBox(height: 20),
          GameMenuButton(
            label: 'DAILY CHALLENGE',
            icon: Icons.public_rounded,
            onPressed:
                onDailyChallenge ??
                () => _showMessage(
                  context,
                  'Daily Challenge requires a connection.',
                ),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'DAILY MISSIONS',
            icon: Icons.flag_outlined,
            onPressed:
                onDailyMissions ??
                () => _showMessage(
                  context,
                  'Daily Missions require a connection.',
                ),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'ACHIEVEMENTS',
            icon: Icons.workspace_premium_outlined,
            onPressed:
                onAchievements ??
                () =>
                    _showMessage(context, 'Achievements require a connection.'),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'LEADERBOARD',
            icon: Icons.emoji_events_outlined,
            onPressed:
                onLeaderboard ??
                () => _showMessage(context, 'Leaderboard will be added later.'),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'SKINS',
            icon: Icons.palette_outlined,
            onPressed:
                onSkins ??
                () => _showMessage(context, 'Skins will be added later.'),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'PROFILE',
            icon: Icons.person_outline_rounded,
            onPressed:
                onProfile ??
                () => _showMessage(context, 'Profile will be added later.'),
          ),
          const SizedBox(height: 12),
          GameMenuButton(
            label: 'SETTINGS',
            icon: Icons.settings_outlined,
            onPressed:
                onSettings ??
                () => _showMessage(context, 'Settings are unavailable.'),
          ),
        ],
      ),
    );
  }
}
