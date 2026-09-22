import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_exception.dart';
import '../../../core/data/repository_support.dart';
import '../models/game_score.dart';
import '../models/game_result.dart';

class GameScoreRepository {
  GameScoreRepository(this._client);
  final SupabaseClient _client;

  Future<SavedGameResult> submitGameResult(GameResult result) =>
      dataOperation(() async {
        requireUserId(_client);
        try {
          result.validate();
        } on FormatException {
          throw const DataException(DataError.invalidInput);
        }
        final response = await _client.rpc(
          'submit_game_result',
          params: result.toRpcParams(),
        );
        final saved = SavedGameResult.fromJson(response);
        saved.validateFor(result);
        return saved;
      });

  Future<List<GameScore>> fetchRecent({int limit = 20, int offset = 0}) =>
      dataOperation(() async {
        final id = requireUserId(_client);
        if (limit < 1 || limit > 100 || offset < 0) {
          throw const DataException(DataError.invalidInput);
        }
        final rows = await _client
            .from('game_scores')
            .select()
            .eq('user_id', id)
            .order('played_at', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map(GameScore.fromJson).toList(growable: false);
      });

  Future<GameScore?> fetchBest() => dataOperation(() async {
    final id = requireUserId(_client);
    final row = await _client
        .from('game_scores')
        .select()
        .eq('user_id', id)
        .order('score', ascending: false)
        .order('played_at', ascending: false)
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : GameScore.fromJson(row);
  });
}
