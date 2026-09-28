class DailyMissionDefinition {
  const DailyMissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.reward,
  });

  final String id;
  final String title;
  final String description;
  final String metric;
  final int target;
  final int reward;
}

abstract final class DailyChallengeRules {
  static const rankedAttemptLimit = 3;

  static DateTime utcDate(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static int seedForUtcDate(DateTime value) {
    final date = utcDate(value);
    final key = date.year * 10000 + date.month * 100 + date.day;
    return (key * 1103515245 + 12345) % 2147483647;
  }

  static List<DailyMissionDefinition> missionsForUtcDate(DateTime value) {
    final date = utcDate(value);
    final ordinal = date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final coinTarget = 15 + (ordinal % 3) * 5;
    final scoreTarget = 600 + (ordinal % 3) * 200;
    final style = switch (ordinal % 5) {
      0 => const DailyMissionDefinition(
        id: 'perfect_landings',
        title: 'CENTER STAGE',
        description: 'Make 3 perfect landings',
        metric: 'perfect_landings',
        target: 3,
        reward: 10,
      ),
      1 => const DailyMissionDefinition(
        id: 'perfect_streak',
        title: 'TRIPLE PERFECT',
        description: 'Reach a perfect streak of 3',
        metric: 'perfect_streak',
        target: 3,
        reward: 10,
      ),
      2 => const DailyMissionDefinition(
        id: 'near_misses',
        title: 'CLOSE CALLS',
        description: 'Record 2 near misses',
        metric: 'near_misses',
        target: 2,
        reward: 10,
      ),
      3 => const DailyMissionDefinition(
        id: 'moving_landings',
        title: 'MOVING TARGET',
        description: 'Land on 3 moving platforms',
        metric: 'moving_landings',
        target: 3,
        reward: 10,
      ),
      _ => const DailyMissionDefinition(
        id: 'reach_storm',
        title: 'WEATHER THE STORM',
        description: 'Reach the Storm biome',
        metric: 'reach_storm',
        target: 1,
        reward: 10,
      ),
    };
    return [
      DailyMissionDefinition(
        id: 'collect_coins',
        title: 'POCKET CHANGE',
        description: 'Collect $coinTarget coins',
        metric: 'coins',
        target: coinTarget,
        reward: 5,
      ),
      DailyMissionDefinition(
        id: 'reach_score',
        title: 'CLIMB HIGH',
        description: 'Reach score $scoreTarget',
        metric: 'score',
        target: scoreTarget,
        reward: 10,
      ),
      style,
    ];
  }
}

class StreakState {
  const StreakState(this.current, this.best, this.lastDate);
  final int current;
  final int best;
  final DateTime? lastDate;
}

abstract final class DailyStreakRules {
  static StreakState qualify(StreakState previous, DateTime activity) {
    final today = DailyChallengeRules.utcDate(activity);
    final last = previous.lastDate == null
        ? null
        : DailyChallengeRules.utcDate(previous.lastDate!);
    if (last == today) return previous;
    final consecutive = last != null && today.difference(last).inDays == 1;
    final current = consecutive ? previous.current + 1 : 1;
    return StreakState(
      current,
      current > previous.best ? current : previous.best,
      today,
    );
  }
}
