import '../../../core/data/json_fields.dart';

/// Deliberately has no account ID, email or authentication metadata.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    this.avatarUrl,
    required this.bestScore,
    required this.bestHeight,
    required this.playedAt,
    required this.isCurrentUser,
  });
  final int rank;
  final String displayName;
  final String? avatarUrl;
  final int bestScore;
  final int bestHeight;
  final DateTime playedAt;
  final bool isCurrentUser;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rank = JsonFields.nonNegativeInt(json, 'rank');
    if (rank < 1 || json['is_current_user'] is! bool) {
      throw const FormatException('Invalid leaderboard entry.');
    }
    final name = JsonFields.optionalText(json, 'display_name')?.trim();
    final url = JsonFields.optionalText(json, 'avatar_url');
    final uri = url == null ? null : Uri.tryParse(url);
    return LeaderboardEntry(
      rank: rank,
      displayName: name == null || name.isEmpty ? 'Player' : name,
      avatarUrl:
          uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
          ? url
          : null,
      bestScore: JsonFields.nonNegativeInt(json, 'best_score'),
      bestHeight: JsonFields.nonNegativeInt(json, 'best_height'),
      playedAt: JsonFields.timestamp(json, 'played_at'),
      isCurrentUser: json['is_current_user'] as bool,
    );
  }
}
