import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_exception.dart';
import '../../../core/data/repository_support.dart';
import '../../game/models/game_result.dart';
import '../../leaderboard/models/leaderboard_entry.dart';
import '../../ads/rewarded_bonus_claim.dart';
import '../models/progression_snapshot.dart';

enum LeaderboardPeriod { daily, weekly, allTime }

typedef LoadProgression = Future<ProgressionSnapshot> Function();
typedef ClaimProgressionReward = Future<RewardClaim> Function(
  RewardKind kind,
  String id,
);
typedef LoadCompetitionLeaderboard = Future<List<LeaderboardEntry>> Function(
  LeaderboardPeriod period,
);

class ProgressionRepository {
  ProgressionRepository(this._client);

  final SupabaseClient _client;

  Future<ProgressionSnapshot> fetchSnapshot() => dataOperation(() async {
    requireUserId(_client);
    return ProgressionSnapshot.fromJson(
      await _client.rpc('get_progression_snapshot'),
    );
  });

  Future<SavedGameResult> submitGameResult(GameResult result) =>
      _submit('submit_progression_result', result);

  Future<SavedGameResult> submitDailyResult(
    DateTime challengeDate,
    GameResult result,
  ) => _submit(
    'submit_daily_challenge_result',
    result,
    extra: {
      'p_challenge_date': challengeDate.toUtc().toIso8601String().substring(
        0,
        10,
      ),
    },
  );

  Future<SavedGameResult> _submit(
    String function,
    GameResult result, {
    Map<String, dynamic> extra = const {},
  }) => dataOperation(() async {
    requireUserId(_client);
    try {
      result.validate();
    } on FormatException {
      throw const DataException(DataError.invalidInput);
    }
    final response = await _client.rpc(
      function,
      params: {...result.toProgressionRpcParams(), ...extra},
    );
    final saved = SavedGameResult.fromJson(response);
    saved.validateFor(result);
    return saved;
  });

  Future<RewardClaim> claimReward(RewardKind kind, String id) =>
      dataOperation(() async {
        requireUserId(_client);
        if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(id)) {
          throw const DataException(DataError.invalidInput);
        }
        return RewardClaim.fromJson(
          await _client.rpc(
            'claim_progression_reward',
            params: {'p_reward_type': kind.name, 'p_reward_id': id},
          ),
        );
      });

  Future<RewardedBonusClaim> claimRewardedRunBonus(String runId) =>
      dataOperation(() async {
        requireUserId(_client);
        if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(runId)) {
          throw const DataException(DataError.invalidInput);
        }
        final claim = RewardedBonusClaim.fromJson(
          await _client.rpc(
            'claim_rewarded_run_bonus',
            params: {'p_run_id': runId},
          ),
        );
        if (claim.runId != runId || claim.bonusCoins > 25) {
          throw const FormatException('Rewarded bonus does not match run.');
        }
        return claim;
      });

  Future<List<LeaderboardEntry>> fetchLeaderboard(
    LeaderboardPeriod period, {
    int limit = 50,
  }) => dataOperation(() async {
    requireUserId(_client);
    if (limit < 1 || limit > 100) {
      throw const DataException(DataError.invalidInput);
    }
    final rows = await _client.rpc(
      'get_competition_leaderboard',
      params: {
        'p_scope': switch (period) {
          LeaderboardPeriod.daily => 'daily',
          LeaderboardPeriod.weekly => 'weekly',
          LeaderboardPeriod.allTime => 'all_time',
        },
        'p_limit': limit,
      },
    );
    if (rows is! List || rows.length > limit) {
      throw const FormatException('Invalid leaderboard.');
    }
    return rows
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Invalid leaderboard entry.');
          }
          return LeaderboardEntry.fromJson(row);
        })
        .toList(growable: false);
  });
}
