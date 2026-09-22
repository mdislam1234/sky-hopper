import '../../../core/data/json_fields.dart';

class UserSkin {
  const UserSkin({
    required this.userId,
    required this.skinId,
    required this.unlockedAt,
  });
  final String userId;
  final String skinId;
  final DateTime unlockedAt;

  factory UserSkin.fromJson(Map<String, dynamic> json) => UserSkin(
    userId: JsonFields.text(json, 'user_id'),
    skinId: JsonFields.text(json, 'skin_id'),
    unlockedAt: JsonFields.timestamp(json, 'unlocked_at'),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'skin_id': skinId,
    'unlocked_at': unlockedAt.toUtc().toIso8601String(),
  };
}
