import 'dart:math';

import '../../../core/data/json_fields.dart';

/// Frozen once at Game Over. A retry reuses every field, including the UUID.
class GameResult {
  const GameResult({
    required this.runId,
    required this.score,
    required this.height,
    required this.coinsCollected,
  });
  final String runId;
  final int score;
  final int height;
  final int coinsCollected;

  static String newRunId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void validate() {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(runId) ||
        [score, height, coinsCollected].any((n) => n < 0 || n > 2147483647)) {
      throw const FormatException('Invalid game result.');
    }
  }

  Map<String, dynamic> toRpcParams() {
    validate();
    return {
      'p_run_id': runId,
      'p_score': score,
      'p_height': height,
      'p_coins_collected': coinsCollected,
    };
  }
}

class SavedGameResult {
  const SavedGameResult({
    required this.runId,
    required this.gameScoreId,
    required this.score,
    required this.height,
    required this.coinsCollected,
    required this.totalCoins,
    required this.playedAt,
    required this.profileUpdatedAt,
  });
  final String runId;
  final int gameScoreId;
  final int score;
  final int height;
  final int coinsCollected;
  final int totalCoins;
  final DateTime playedAt;
  final DateTime profileUpdatedAt;

  factory SavedGameResult.fromJson(Object? response) {
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved result.');
    }
    final id = response['game_score_id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid result ID.');
    }
    return SavedGameResult(
      runId: JsonFields.text(response, 'run_id'),
      gameScoreId: id,
      score: JsonFields.nonNegativeInt(response, 'saved_score'),
      height: JsonFields.nonNegativeInt(response, 'saved_height'),
      coinsCollected: JsonFields.nonNegativeInt(response, 'coins_collected'),
      totalCoins: JsonFields.nonNegativeInt(response, 'new_total_coins'),
      playedAt: JsonFields.timestamp(response, 'played_at'),
      profileUpdatedAt: JsonFields.timestamp(response, 'profile_updated_at'),
    );
  }

  void validateFor(GameResult result) {
    if (runId != result.runId ||
        score != result.score ||
        height != result.height ||
        coinsCollected != result.coinsCollected ||
        totalCoins < coinsCollected) {
      throw const FormatException('Saved result does not match this run.');
    }
  }
}

typedef SubmitGameResult = Future<SavedGameResult> Function(GameResult result);
