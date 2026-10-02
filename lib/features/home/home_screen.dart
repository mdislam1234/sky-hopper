import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_menu_button.dart';
import '../../core/widgets/sky_page.dart';
import '../profile/models/profile.dart';
import 'widgets/home_action_card.dart';
import 'widgets/home_hero.dart';
import 'widgets/player_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    this.profile,
    this.playerName,
    this.avatarUrl,
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
  final String? avatarUrl;
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
        label: 'Daily Challenge',
        icon: Icons.event_available_rounded,
        accentColor: AppColors.orange,
        onPressed: _action(
          context,
          onDailyChallenge,
          'Daily Challenge requires a connection.',
        ),
      ),
      _HomeAction(
        label: 'Missions',
        icon: Icons.flag_outlined,
        accentColor: AppColors.coral,
        onPressed: _action(
          context,
          onDailyMissions,
          'Daily Missions require a connection.',
        ),
      ),
      _HomeAction(
        label: 'Achievements',
        icon: Icons.workspace_premium_outlined,
        accentColor: AppColors.orange,
        onPressed: _action(
          context,
          onAchievements,
          'Achievements require a connection.',
        ),
      ),
      _HomeAction(
        label: 'Leaderboard',
        icon: Icons.emoji_events_outlined,
        accentColor: AppColors.gold,
        onPressed: _action(
          context,
          onLeaderboard,
          'Leaderboard is unavailable.',
        ),
      ),
      _HomeAction(
        label: 'Skins',
        icon: Icons.palette_outlined,
        accentColor: AppColors.purple,
        onPressed: _action(context, onSkins, 'Skins are unavailable.'),
      ),
      _HomeAction(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        accentColor: AppColors.royalBlue,
        onPressed: _action(context, onProfile, 'Profile is unavailable.'),
      ),
    ];

    final media = MediaQuery.of(context);
    final compact =
        media.size.height < 700 || media.orientation == Orientation.landscape;
    final sectionGap = compact ? 10.0 : 14.0;

    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHero(key: const ValueKey('home-hero'), compact: compact),
          SizedBox(height: compact ? 4 : 8),
          PlayerSummaryCard(
            key: const ValueKey('home-player-summary'),
            playerName:
                playerName ??
                (profile?.displayName?.trim().isNotEmpty ?? false
                    ? profile!.displayName!
                    : 'Guest Player'),
            coins: profile?.totalCoins ?? 0,
            isGuest: isGuest,
            avatarUrl: avatarUrl ?? profile?.avatarUrl,
            onPressed: onProfile,
          ),
          SizedBox(height: sectionGap),
          GameMenuButton(
            label: 'PLAY',
            icon: Icons.play_arrow_rounded,
            primary: true,
            onPressed: _action(context, onPlay, 'Game mode is unavailable.'),
          ),
          SizedBox(height: sectionGap + 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final scaledBody = MediaQuery.textScalerOf(context).scale(16);
              final useSingleColumn =
                  constraints.maxWidth < 300 && scaledBody > 22;
              final tileHeight = scaledBody > 25
                  ? 102.0
                  : scaledBody > 19
                  ? 88.0
                  : compact
                  ? 68.0
                  : 74.0;
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
                    accentColor: action.accentColor,
                    allowWrap: action.label == 'Daily Challenge',
                    onPressed: action.onPressed,
                  );
                },
              );
            },
          ),
          SizedBox(height: sectionGap),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              key: const ValueKey('home-settings'),
              width: 240,
              height: compact ? 64 : 70,
              child: HomeActionCard(
                label: 'Settings',
                icon: Icons.settings_rounded,
                accentColor: AppColors.deepBlue,
                centered: true,
                onPressed: _action(
                  context,
                  onSettings,
                  'Settings are unavailable.',
                ),
              ),
            ),
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
    required this.accentColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;
}
