import '../../core/data/json_fields.dart';

class RewardedBonusClaim {
  const RewardedBonusClaim({
    required this.runId,
    required this.bonusCoins,
    required this.totalCoins,
    required this.alreadyClaimed,
    required this.profileUpdatedAt,
  });

  final String runId;
  final int bonusCoins;
  final int totalCoins;
  final bool alreadyClaimed;
  final DateTime profileUpdatedAt;

  factory RewardedBonusClaim.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['already_claimed'] is! bool) {
      throw const FormatException('Invalid rewarded bonus claim.');
    }
    return RewardedBonusClaim(
      runId: JsonFields.text(value, 'run_id'),
      bonusCoins: JsonFields.nonNegativeInt(value, 'bonus_coins'),
      totalCoins: JsonFields.nonNegativeInt(value, 'new_total_coins'),
      alreadyClaimed: value['already_claimed'] as bool,
      profileUpdatedAt: JsonFields.timestamp(value, 'profile_updated_at'),
    );
  }
}

typedef ClaimRewardedRunBonus = Future<RewardedBonusClaim> Function(
  String runId,
);

/// Prevents duplicate client claim calls while retaining retry after failure.
class RewardedClaimGate {
  bool _inFlight = false;
  bool _completed = false;

  bool get completed => _completed;

  bool tryStart() {
    if (_inFlight || _completed) return false;
    _inFlight = true;
    return true;
  }

  void complete() {
    _inFlight = false;
    _completed = true;
  }

  void releaseForRetry() => _inFlight = false;
}
