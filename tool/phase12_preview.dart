// Development-only Phase 12 inspector. It is never imported by production
// main.dart, creates no Supabase client, and keeps every mutation in memory.
import 'package:flutter/material.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/core/widgets/sky_page.dart';
import 'package:sky_hopper/features/leaderboard/leaderboard_screen.dart';
import 'package:sky_hopper/features/leaderboard/models/leaderboard_entry.dart';
import 'package:sky_hopper/features/progression/daily_challenge_screen.dart';
import 'package:sky_hopper/features/progression/data/progression_repository.dart';
import 'package:sky_hopper/features/progression/models/daily_challenge_rules.dart';
import 'package:sky_hopper/features/progression/models/progression_snapshot.dart';
import 'package:sky_hopper/features/progression/progression_goals_screen.dart';

void main() => runApp(const _Phase12PreviewApp());

class _Phase12PreviewApp extends StatelessWidget {
  const _Phase12PreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sky Hopper Phase 12 Preview',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) => Banner(
      message: 'DEV ONLY',
      location: BannerLocation.topEnd,
      child: child!,
    ),
    home: const _PreviewHome(),
  );
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  int dateOffset = 0;
  int attemptsUsed = 2;
  final claimed = <String>{'mission:score'};

  DateTime get date => DateTime.utc(2026, 9, 27 + dateOffset);

  List<ProgressionGoal> get missions => [
    ProgressionGoal(
      id: 'coins',
      title: 'Cloud Collector',
      description: 'Collect 25 coins today.',
      progress: 25,
      target: 25,
      reward: 15,
      completed: true,
      claimed: claimed.contains('mission:coins'),
      icon: 'coin',
    ),
    ProgressionGoal(
      id: 'score',
      title: 'Sky Sprint',
      description: 'Score 1,000 points today.',
      progress: 1000,
      target: 1000,
      reward: 20,
      completed: true,
      claimed: true,
      icon: 'flight',
    ),
    const ProgressionGoal(
      id: 'perfect',
      title: 'Stick the Landing',
      description: 'Make 8 perfect landings today.',
      progress: 5,
      target: 8,
      reward: 20,
      completed: false,
      claimed: false,
      icon: 'perfect',
    ),
  ];

  List<ProgressionGoal> get achievements => [
    ProgressionGoal(
      id: 'first_flight',
      title: 'First Flight',
      description: 'Complete your first saved run.',
      progress: 1,
      target: 1,
      reward: 10,
      completed: true,
      claimed: claimed.contains('achievement:first_flight'),
      icon: 'flight',
    ),
    const ProgressionGoal(
      id: 'storm_chaser',
      title: 'Storm Chaser',
      description: 'Reach the Storm biome 10 times.',
      progress: 7,
      target: 10,
      reward: 75,
      completed: false,
      claimed: false,
      icon: 'storm',
    ),
    const ProgressionGoal(
      id: 'consistent',
      title: 'Consistent',
      description: 'Build a 7-day play streak.',
      progress: 4,
      target: 7,
      reward: 100,
      completed: false,
      claimed: false,
      icon: 'streak',
    ),
  ];

  ProgressionSnapshot get snapshot => ProgressionSnapshot(
    challengeDate: date,
    challengeSeed: DailyChallengeRules.seedForUtcDate(date),
    attemptsUsed: attemptsUsed,
    attemptLimit: DailyChallengeRules.rankedAttemptLimit,
    dailyBest: 1280,
    weeklyBest: 1760,
    allTimeBest: 2310,
    topDailyScore: 1985,
    currentStreak: 4,
    bestStreak: 9,
    missions: missions,
    achievements: achievements,
  );

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<ProgressionSnapshot> loadSnapshot() async => snapshot;

  Future<RewardClaim> claim(RewardKind kind, String id) async {
    final key = '${kind.name}:$id';
    final alreadyClaimed = claimed.contains(key);
    setState(() => claimed.add(key));
    return RewardClaim(
      id: id,
      kind: kind,
      rewardGranted: alreadyClaimed ? 0 : 25,
      totalCoins: 247,
      alreadyClaimed: alreadyClaimed,
    );
  }

  List<LeaderboardEntry> leaderboard(LeaderboardPeriod period) {
    final multiplier = switch (period) {
      LeaderboardPeriod.daily => 1,
      LeaderboardPeriod.weekly => 2,
      LeaderboardPeriod.allTime => 3,
    };
    return [
      LeaderboardEntry(
        rank: 1,
        displayName: 'CloudPilot',
        bestScore: 810 * multiplier,
        bestHeight: 8100 * multiplier,
        playedAt: date,
        isCurrentUser: false,
      ),
      LeaderboardEntry(
        rank: 2,
        displayName: 'Sky Hopper',
        bestScore: 640 * multiplier,
        bestHeight: 6400 * multiplier,
        playedAt: date,
        isCurrentUser: true,
      ),
      LeaderboardEntry(
        rank: 3,
        displayName: 'Nimbus',
        bestScore: 575 * multiplier,
        bestHeight: 5750 * multiplier,
        playedAt: date,
        isCurrentUser: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => SkyPage(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PHASE 12 INSPECTOR',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Synthetic data only · no authentication · no persistence',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const Text('UTC DATE'),
        Wrap(
          spacing: 8,
          children: [
            for (final offset in const [0, 1, 2])
              ChoiceChip(
                label: Text('SEP ${27 + offset}'),
                selected: dateOffset == offset,
                onSelected: (_) => setState(() => dateOffset = offset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('RANKED ATTEMPTS USED'),
        Wrap(
          spacing: 8,
          children: [
            for (final count in const [0, 2, 3])
              ChoiceChip(
                label: Text('$count / 3'),
                selected: attemptsUsed == count,
                onSelected: (_) => setState(() => attemptsUsed = count),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => open(
            DailyChallengeScreen(
              load: loadSnapshot,
              onPlay: (_, ranked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ranked
                          ? 'Ranked daily preview selected.'
                          : 'Unsaved practice preview selected.',
                    ),
                  ),
                );
              },
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          icon: const Icon(Icons.public_rounded),
          label: const Text('DAILY CHALLENGE'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => open(
            ProgressionGoalsScreen(
              kind: RewardKind.mission,
              load: loadSnapshot,
              claim: claim,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('DAILY MISSIONS'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => open(
            ProgressionGoalsScreen(
              kind: RewardKind.achievement,
              load: loadSnapshot,
              claim: claim,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('ACHIEVEMENTS'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => open(
            LeaderboardScreen(
              load: () async => leaderboard(LeaderboardPeriod.allTime),
              loadPeriod: (period) async => leaderboard(period),
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('LEADERBOARDS'),
        ),
        const SizedBox(height: 12),
        Text(
          'Seed ${snapshot.challengeSeed} · ${snapshot.attemptsRemaining} ranked attempts remaining',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
