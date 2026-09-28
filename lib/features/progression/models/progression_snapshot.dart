import '../../../core/data/json_fields.dart';

enum RewardKind { mission, achievement }

class ProgressionGoal {
  const ProgressionGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.reward,
    required this.completed,
    required this.claimed,
    this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;
  final int reward;
  final bool completed;
  final bool claimed;
  final String? icon;

  double get completion => target == 0 ? 0 : (progress / target).clamp(0, 1);
  bool get canClaim => completed && !claimed;

  factory ProgressionGoal.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'];
    final claimed = json['claimed'];
    if (completed is! bool || claimed is! bool) {
      throw const FormatException('Invalid progression goal.');
    }
    final target = JsonFields.nonNegativeInt(json, 'target');
    if (target < 1) throw const FormatException('Invalid goal target.');
    return ProgressionGoal(
      id: JsonFields.text(json, 'id'),
      title: JsonFields.text(json, 'title'),
      description: JsonFields.text(json, 'description'),
      progress: JsonFields.nonNegativeInt(json, 'progress'),
      target: target,
      reward: JsonFields.nonNegativeInt(json, 'reward'),
      completed: completed,
      claimed: claimed,
      icon: JsonFields.optionalText(json, 'icon'),
    );
  }
}

class ProgressionSnapshot {
  const ProgressionSnapshot({
    required this.challengeDate,
    required this.challengeSeed,
    required this.attemptsUsed,
    required this.attemptLimit,
    required this.dailyBest,
    required this.weeklyBest,
    required this.allTimeBest,
    required this.topDailyScore,
    required this.currentStreak,
    required this.bestStreak,
    required this.missions,
    required this.achievements,
  });

  final DateTime challengeDate;
  final int challengeSeed;
  final int attemptsUsed;
  final int attemptLimit;
  final int dailyBest;
  final int weeklyBest;
  final int allTimeBest;
  final int topDailyScore;
  final int currentStreak;
  final int bestStreak;
  final List<ProgressionGoal> missions;
  final List<ProgressionGoal> achievements;

  int get attemptsRemaining =>
      (attemptLimit - attemptsUsed).clamp(0, attemptLimit);
  bool get rankedAttemptAvailable => attemptsRemaining > 0;

  factory ProgressionSnapshot.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid progression snapshot.');
    }
    final date = DateTime.tryParse(JsonFields.text(value, 'challenge_date'));
    final missions = value['missions'];
    final achievements = value['achievements'];
    if (date == null || missions is! List || achievements is! List) {
      throw const FormatException('Invalid progression snapshot.');
    }
    final attemptLimit = JsonFields.nonNegativeInt(value, 'attempt_limit');
    final attemptsUsed = JsonFields.nonNegativeInt(value, 'attempts_used');
    if (attemptLimit < 1 || attemptsUsed > attemptLimit) {
      throw const FormatException('Invalid daily attempts.');
    }
    List<ProgressionGoal> parseGoals(List rows) => rows
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Invalid progression goal.');
          }
          return ProgressionGoal.fromJson(row);
        })
        .toList(growable: false);
    return ProgressionSnapshot(
      challengeDate: DateTime.utc(date.year, date.month, date.day),
      challengeSeed: JsonFields.nonNegativeInt(value, 'challenge_seed'),
      attemptsUsed: attemptsUsed,
      attemptLimit: attemptLimit,
      dailyBest: JsonFields.nonNegativeInt(value, 'daily_best'),
      weeklyBest: JsonFields.nonNegativeInt(value, 'weekly_best'),
      allTimeBest: JsonFields.nonNegativeInt(value, 'all_time_best'),
      topDailyScore: JsonFields.nonNegativeInt(value, 'top_daily_score'),
      currentStreak: JsonFields.nonNegativeInt(value, 'current_streak'),
      bestStreak: JsonFields.nonNegativeInt(value, 'best_streak'),
      missions: parseGoals(missions),
      achievements: parseGoals(achievements),
    );
  }
}

class RewardClaim {
  const RewardClaim({
    required this.id,
    required this.kind,
    required this.rewardGranted,
    required this.totalCoins,
    required this.alreadyClaimed,
  });

  final String id;
  final RewardKind kind;
  final int rewardGranted;
  final int totalCoins;
  final bool alreadyClaimed;

  factory RewardClaim.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['already_claimed'] is! bool) {
      throw const FormatException('Invalid reward claim.');
    }
    final kind = switch (JsonFields.text(value, 'reward_type')) {
      'mission' => RewardKind.mission,
      'achievement' => RewardKind.achievement,
      _ => throw const FormatException('Invalid reward type.'),
    };
    return RewardClaim(
      id: JsonFields.text(value, 'reward_id'),
      kind: kind,
      rewardGranted: JsonFields.nonNegativeInt(value, 'reward_granted'),
      totalCoins: JsonFields.nonNegativeInt(value, 'new_total_coins'),
      alreadyClaimed: value['already_claimed'] as bool,
    );
  }
}
