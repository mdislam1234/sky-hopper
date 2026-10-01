import 'package:flutter/material.dart';

import '../../core/widgets/game_menu_button.dart';
import '../../core/widgets/sky_hopper_logo.dart';
import '../../core/widgets/sky_page.dart';
import '../profile/models/profile.dart';
import 'widgets/home_action_card.dart';
import 'widgets/player_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    this.profile,
    this.playerName,
    this.isGuest = false,
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
  final String? playerName;
  final bool isGuest;
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

  VoidCallback _action(
    BuildContext context,
    VoidCallback? callback,
    String fallback,
  ) => callback ?? () => _showMessage(context, fallback);

  @override
  Widget build(BuildContext context) {
    final actions = [
      _HomeAction(
        label: 'DAILY CHALLENGE',
        icon: Icons.event_available_rounded,
        onPressed: _action(
          context,
          onDailyChallenge,
          'Daily Challenge requires a connection.',
        ),
      ),
      _HomeAction(
        label: 'MISSIONS',
        icon: Icons.flag_outlined,
        onPressed: _action(
          context,
          onDailyMissions,
          'Daily Missions require a connection.',
        ),
      ),
      _HomeAction(
        label: 'ACHIEVEMENTS',
        icon: Icons.workspace_premium_outlined,
        onPressed: _action(
          context,
          onAchievements,
          'Achievements require a connection.',
        ),
      ),
      _HomeAction(
        label: 'LEADERBOARD',
        icon: Icons.emoji_events_outlined,
        onPressed: _action(
          context,
          onLeaderboard,
          'Leaderboard is unavailable.',
        ),
      ),
      _HomeAction(
        label: 'SKINS',
        icon: Icons.palette_outlined,
        onPressed: _action(context, onSkins, 'Skins are unavailable.'),
      ),
      _HomeAction(
        label: 'PROFILE',
        icon: Icons.person_outline_rounded,
        onPressed: _action(context, onProfile, 'Profile is unavailable.'),
      ),
    ];

    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 52),
                child: SkyHopperLogo(compact: true),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  key: const ValueKey('home-settings'),
                  onPressed: _action(
                    context,
                    onSettings,
                    'Settings are unavailable.',
                  ),
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Jump higher. Beat your best.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          PlayerSummaryCard(
            key: const ValueKey('home-player-summary'),
            playerName:
                playerName ??
                (profile?.displayName?.trim().isNotEmpty ?? false
                    ? profile!.displayName!
                    : 'Guest Player'),
            coins: profile?.totalCoins ?? 0,
            isGuest: isGuest,
            onPressed: onProfile,
          ),
          const SizedBox(height: 16),
          GameMenuButton(
            label: 'PLAY',
            icon: Icons.play_arrow_rounded,
            primary: true,
            onPressed: _action(context, onPlay, 'Game mode is unavailable.'),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final scaledBody = MediaQuery.textScalerOf(context).scale(16);
              final useSingleColumn =
                  constraints.maxWidth < 300 && scaledBody > 22;
              final tileHeight = scaledBody > 25
                  ? 104.0
                  : scaledBody > 19
                  ? 90.0
                  : 78.0;
              return GridView.builder(
                key: const ValueKey('home-action-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: useSingleColumn ? 1 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return HomeActionCard(
                    key: ValueKey('home-${action.label.toLowerCase()}'),
                    label: action.label,
                    icon: action.icon,
                    onPressed: action.onPressed,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}
