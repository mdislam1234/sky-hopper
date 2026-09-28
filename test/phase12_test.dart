import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/game/models/game_result.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/leaderboard/leaderboard_screen.dart';
import 'package:sky_hopper/features/leaderboard/models/leaderboard_entry.dart';
import 'package:sky_hopper/features/progression/daily_challenge_screen.dart';
import 'package:sky_hopper/features/progression/data/progression_repository.dart';
import 'package:sky_hopper/features/progression/models/daily_challenge_rules.dart';
import 'package:sky_hopper/features/progression/models/progression_snapshot.dart';
import 'package:sky_hopper/features/progression/progression_goals_screen.dart';

void main() {
  group('UTC daily challenge', () {
    test('same UTC date produces the same seed across local offsets', () {
      final a = DateTime.parse('2026-09-27T00:05:00Z');
      final b = DateTime.parse('2026-09-27T23:55:00Z').toLocal();
      expect(
        DailyChallengeRules.seedForUtcDate(a),
        DailyChallengeRules.seedForUtcDate(b),
      );
    });

    test('next UTC date produces a different seed', () {
      expect(
        DailyChallengeRules.seedForUtcDate(DateTime.utc(2026, 9, 27)),
        isNot(DailyChallengeRules.seedForUtcDate(DateTime.utc(2026, 9, 28))),
      );
    });

    test('same seed reproduces platform generation', () {
      List<String> sample(int seed) {
        final generator = PlatformGenerator(Random(seed));
        final values = generator.initial();
        while (values.length < 18) {
          values.add(generator.next(values.last, score: values.length * 140));
        }
        return values
            .map(
              (p) =>
                  '${p.type.name}:${p.x.toStringAsFixed(4)}:'
                  '${p.y.toStringAsFixed(4)}:${p.width.toStringAsFixed(4)}',
            )
            .toList();
      }

      final seed = DailyChallengeRules.seedForUtcDate(
        DateTime.utc(2026, 9, 27),
      );
      expect(sample(seed), sample(seed));
    });

    test('daily rules do not change the normal GameState default seed', () {
      expect(GameState().seed, 5);
      expect(
        GameState(
          seed: DailyChallengeRules.seedForUtcDate(DateTime.utc(2026, 9, 27)),
        ).seed,
        isNot(5),
      );
    });

    test('daily mission selection is deterministic and rolls over', () {
      final date = DateTime.utc(2026, 9, 27);
      final today = DailyChallengeRules.missionsForUtcDate(date);
      expect(
        today.map((m) => m.id),
        DailyChallengeRules.missionsForUtcDate(date).map((m) => m.id),
      );
      expect(today, hasLength(3));
      expect(today.map((m) => m.metric), containsAll(['coins', 'score']));
      expect(
        DailyChallengeRules.missionsForUtcDate(
          date.add(const Duration(days: 1)),
        ).map((m) => '${m.id}:${m.target}'),
        isNot(today.map((m) => '${m.id}:${m.target}')),
      );
    });
  });

  group('progression models', () {
    test('attempt limit exposes ranked then practice behavior', () {
      expect(snapshot(attempts: 2).rankedAttemptAvailable, isTrue);
      expect(snapshot(attempts: 2).attemptsRemaining, 1);
      expect(snapshot(attempts: 3).rankedAttemptAvailable, isFalse);
      expect(snapshot(attempts: 3).attemptsRemaining, 0);
    });

    test('goal completion exposes claim exactly until claimed', () {
      expect(goal(progress: 3, completed: true).canClaim, isTrue);
      expect(
        goal(progress: 3, completed: true, claimed: true).canClaim,
        isFalse,
      );
      expect(goal(progress: 2).canClaim, isFalse);
    });

    test('snapshot parser rejects private or malformed structures', () {
      expect(
        () => ProgressionSnapshot.fromJson({'email': 'private@example.test'}),
        throwsFormatException,
      );
    });

    test('reward claim parses server amount without client pricing input', () {
      final claim = RewardClaim.fromJson({
        'reward_type': 'mission',
        'reward_id': 'reach_score',
        'reward_granted': 10,
        'new_total_coins': 232,
        'already_claimed': false,
      });
      expect(claim.rewardGranted, 10);
      expect(claim.totalCoins, 232);
    });
  });

  group('run metrics', () {
    test('progression parameters retain the immutable run UUID', () {
      const result = GameResult(
        runId: '123e4567-e89b-42d3-a456-426614174000',
        score: 1200,
        height: 12000,
        coinsCollected: 20,
        perfectLandings: 4,
        bestPerfectStreak: 3,
        nearMisses: 2,
        movingPlatformLandings: 5,
        highestBiome: 2,
      );
      final params = result.toProgressionRpcParams();
      expect(params['p_run_id'], result.runId);
      expect(params['p_perfect_landings'], 4);
      expect(params['p_highest_biome'], 2);
      expect(result.toRpcParams(), isNot(contains('p_perfect_landings')));
    });

    test('invalid style metrics are rejected before a request', () {
      const result = GameResult(
        runId: '123e4567-e89b-42d3-a456-426614174000',
        score: 1,
        height: 10,
        coinsCollected: 0,
        bestPerfectStreak: 11,
      );
      expect(result.validate, throwsFormatException);
    });

    test('reset clears run-specific progression counters', () {
      final state = GameState()
        ..perfectLandings = 4
        ..bestPerfectStreak = 3
        ..movingPlatformLandings = 2
        ..nearMisses = 5;
      state.reset();
      expect([
        state.perfectLandings,
        state.bestPerfectStreak,
        state.movingPlatformLandings,
        state.nearMisses,
      ], everyElement(0));
    });
  });

  group('server migration contract', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20260927235931_phase12_progression.sql')
          .readAsStringSync();
    });

    test('all user progression tables enable RLS', () {
      for (final table in [
        'run_progression',
        'daily_challenge_results',
        'daily_missions',
        'user_achievements',
        'player_streaks',
      ]) {
        expect(
          sql,
          contains('alter table public.$table enable row level security'),
        );
      }
    });

    test('mutating functions derive ownership from auth uid', () {
      expect(
        RegExp(r'v_user uuid := auth\.uid\(\)').allMatches(sql),
        hasLength(6),
      );
      expect(sql, isNot(contains('p_user_id')));
    });

    test('daily submission enforces server UTC date and three attempts', () {
      expect(sql, contains("statement_timestamp() at time zone 'utc'"));
      expect(sql, contains('if v_attempt > 3'));
      expect(sql, contains("errcode = 'SH003'"));
    });

    test('run and daily UUID constraints block duplicate consumption', () {
      expect(sql, contains('primary key (user_id, run_id)'));
      expect(sql, contains('unique (user_id, run_id)'));
      expect(sql, contains('on conflict (user_id, run_id) do nothing'));
    });

    test('leaderboard scopes isolate daily weekly and all time', () {
      expect(sql, contains("p_scope not in ('daily', 'weekly', 'all_time')"));
      expect(sql, contains("p_scope = 'daily' and d.challenge_date = v_today"));
      expect(
        sql,
        contains("p_scope = 'weekly' and s.played_at >= v_week_start"),
      );
    });

    test('leaderboard output omits user ids email and provider data', () {
      final signature = sql.substring(
        sql.indexOf('create function public.get_competition_leaderboard'),
        sql.indexOf('-- Two achievement-only cosmetics'),
      );
      expect(signature, contains('is_current_user boolean'));
      expect(signature, isNot(contains('email')));
      expect(signature, isNot(contains('provider')));
      expect(signature, isNot(contains('returns table (\n  user_id')));
    });

    test('reward amount comes from server rows and claims once', () {
      expect(sql, contains('select reward, claimed_at into v_reward'));
      expect(
        sql,
        contains(
          "'reward_granted', case when v_already then 0 else v_reward end",
        ),
      );
      expect(sql, isNot(contains('p_reward_amount')));
    });

    test(
      'direct writes are revoked and RPC execution is authenticated only',
      () {
        expect(sql, contains('revoke all on public.achievement_catalog'));
        expect(sql, contains('from public, anon, authenticated, service_role'));
        expect(sql, contains('to authenticated;'));
      },
    );
  });

  group('return streak', () {
    test('same UTC day does not increment', () {
      final previous = StreakState(3, 3, DateTime.utc(2026, 9, 27, 1));
      final next = DailyStreakRules.qualify(
        previous,
        DateTime.utc(2026, 9, 27, 23),
      );
      expect(next.current, 3);
    });

    test('consecutive UTC day increments', () {
      final next = DailyStreakRules.qualify(
        StreakState(3, 3, DateTime.utc(2026, 9, 27)),
        DateTime.utc(2026, 9, 28),
      );
      expect(next.current, 4);
      expect(next.best, 4);
    });

    test('missed UTC day resets current but preserves best', () {
      final next = DailyStreakRules.qualify(
        StreakState(3, 7, DateTime.utc(2026, 9, 27)),
        DateTime.utc(2026, 9, 29),
      );
      expect(next.current, 1);
      expect(next.best, 7);
    });
  });

  group('Phase 12 UI', () {
    testWidgets('Daily screen shows ranked context and starts ranked', (
      tester,
    ) async {
      bool? ranked;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyChallengeScreen(
            load: () async => snapshot(attempts: 1),
            onPlay: (_, value) => ranked = value,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3 remaining'), findsOneWidget);
      await tester.tap(find.text('PLAY DAILY'));
      expect(ranked, isTrue);
    });

    testWidgets('exhausted attempts offer unsaved practice', (tester) async {
      bool? ranked;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyChallengeScreen(
            load: () async => snapshot(attempts: 3),
            onPlay: (_, value) => ranked = value,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRACTICE DAILY'));
      expect(ranked, isFalse);
      expect(find.textContaining('not saved or ranked'), findsOneWidget);
    });

    testWidgets('Daily Missions exposes a completed claim', (tester) async {
      var claims = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionGoalsScreen(
            kind: RewardKind.mission,
            load: () async =>
                snapshot(mission: goal(progress: 3, completed: true)),
            claim: (kind, id) async {
              claims++;
              return const RewardClaim(
                id: 'reach_score',
                kind: RewardKind.mission,
                rewardGranted: 10,
                totalCoins: 232,
                alreadyClaimed: false,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLAIM'));
      await tester.pumpAndSettle();
      expect(claims, 1);
    });

    testWidgets('Achievements shows programmatic badge and progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionGoalsScreen(
            kind: RewardKind.achievement,
            load: () async => snapshot(achievement: goal(progress: 2)),
            claim: (_, _) => throw UnimplementedError(),
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('leaderboard switches daily weekly and all time responsively', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final periods = <LeaderboardPeriod>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LeaderboardScreen(
            load: () async => [entry()],
            loadPeriod: (period) async {
              periods.add(period);
              return [entry()];
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DAILY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEEKLY'));
      await tester.pumpAndSettle();
      expect(periods, [
        LeaderboardPeriod.allTime,
        LeaderboardPeriod.daily,
        LeaderboardPeriod.weekly,
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}

ProgressionGoal goal({
  int progress = 1,
  bool completed = false,
  bool claimed = false,
}) => ProgressionGoal(
  id: 'reach_score',
  title: 'CLIMB HIGH',
  description: 'Reach score 600',
  progress: progress,
  target: 3,
  reward: 10,
  completed: completed,
  claimed: claimed,
);

ProgressionSnapshot snapshot({
  int attempts = 0,
  ProgressionGoal? mission,
  ProgressionGoal? achievement,
}) => ProgressionSnapshot(
  challengeDate: DateTime.utc(2026, 9, 27),
  challengeSeed: DailyChallengeRules.seedForUtcDate(DateTime.utc(2026, 9, 27)),
  attemptsUsed: attempts,
  attemptLimit: 3,
  dailyBest: 700,
  weeklyBest: 900,
  allTimeBest: 1200,
  topDailyScore: 1500,
  currentStreak: 3,
  bestStreak: 7,
  missions: [mission ?? goal()],
  achievements: [achievement ?? goal()],
);

LeaderboardEntry entry() => LeaderboardEntry.fromJson({
  'rank': 1,
  'display_name': 'Player',
  'avatar_url': null,
  'best_score': 1200,
  'best_height': 12000,
  'played_at': '2026-09-27T10:00:00Z',
  'is_current_user': true,
});
