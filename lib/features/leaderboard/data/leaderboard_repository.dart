import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_exception.dart';
import '../../../core/data/repository_support.dart';
import '../models/leaderboard_entry.dart';

typedef LoadLeaderboard = Future<List<LeaderboardEntry>> Function();

class LeaderboardRepository {
  LeaderboardRepository(this._client);
  final SupabaseClient _client;
  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 50}) =>
      dataOperation(() async {
        requireUserId(_client);
        if (limit < 1 || limit > 100) {
          throw const DataException(DataError.invalidInput);
        }
        final rows = await _client.rpc(
          'get_leaderboard',
          params: {'p_limit': limit},
        );
        if (rows is! List || rows.length > limit) {
          throw const FormatException('Invalid leaderboard.');
        }
        return rows
            .map((row) {
              if (row is! Map<String, dynamic>) {
                throw const FormatException('Invalid entry.');
              }
              return LeaderboardEntry.fromJson(row);
            })
            .toList(growable: false);
      });
}
