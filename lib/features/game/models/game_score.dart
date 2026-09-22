import '../../../core/data/json_fields.dart';

class GameScore {
  const GameScore({
    required this.id,
    required this.userId,
    required this.score,
    required this.height,
    required this.coinsCollected,
    required this.playedAt,
  });
  final int id;
  final String userId;
  final int score;
  final int height;
  final int coinsCollected;
  final DateTime playedAt;

  factory GameScore.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int || id <= 0) throw const FormatException('Invalid score ID.');
    return GameScore(
      id: id,
      userId: JsonFields.text(json, 'user_id'),
      score: JsonFields.nonNegativeInt(json, 'score'),
      height: JsonFields.nonNegativeInt(json, 'height'),
      coinsCollected: JsonFields.nonNegativeInt(
        json,
        'coins_collected',
        fallback: 0,
      ),
      playedAt: JsonFields.timestamp(json, 'played_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'score': score,
    'height': height,
    'coins_collected': coinsCollected,
    'played_at': playedAt.toUtc().toIso8601String(),
  };
}
