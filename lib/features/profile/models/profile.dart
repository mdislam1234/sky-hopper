import '../../../core/data/json_fields.dart';

class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.totalCoins,
    required this.selectedSkin,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int totalCoins;
  final String selectedSkin;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: JsonFields.text(json, 'id'),
    displayName: JsonFields.optionalText(json, 'display_name'),
    avatarUrl: JsonFields.optionalText(json, 'avatar_url'),
    totalCoins: JsonFields.nonNegativeInt(json, 'total_coins', fallback: 0),
    selectedSkin: JsonFields.text(json, 'selected_skin', fallback: 'default'),
    createdAt: JsonFields.timestamp(json, 'created_at'),
    updatedAt: JsonFields.timestamp(json, 'updated_at'),
  );

  /// Full row serialization, not an update payload.
  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'total_coins': totalCoins,
    'selected_skin': selectedSkin,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
