import 'dart:ui';

import '../../../core/data/json_fields.dart';

class SkinAppearance {
  const SkinAppearance(this.primary, this.secondary, this.accent);
  final Color primary;
  final Color secondary;
  final Color accent;
  static const defaultSkin = SkinAppearance(
    Color(0xFFFFD45A),
    Color(0xFFE9A834),
    Color(0xFF123B69),
  );
  static Color parseColor(Object? value, Color fallback) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return fallback;
    }
    return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
  }
}

class Skin {
  const Skin({
    required this.id,
    required this.name,
    this.description,
    required this.cost,
    required this.appearance,
  });
  final String id;
  final String name;
  final String? description;
  final int cost;
  final SkinAppearance appearance;
  factory Skin.fromJson(Map<String, dynamic> json) => Skin(
    id: JsonFields.text(json, 'id'),
    name: JsonFields.text(json, 'name'),
    description: JsonFields.optionalText(json, 'description'),
    cost: JsonFields.nonNegativeInt(json, 'cost'),
    appearance: SkinAppearance(
      SkinAppearance.parseColor(
        json['primary_color'],
        SkinAppearance.defaultSkin.primary,
      ),
      SkinAppearance.parseColor(
        json['secondary_color'],
        SkinAppearance.defaultSkin.secondary,
      ),
      SkinAppearance.parseColor(
        json['accent_color'],
        SkinAppearance.defaultSkin.accent,
      ),
    ),
  );
}

class SkinUnlock {
  const SkinUnlock({
    required this.skinId,
    required this.alreadyOwned,
    required this.costCharged,
    required this.totalCoins,
    required this.unlockedAt,
    required this.profileUpdatedAt,
  });
  final String skinId;
  final bool alreadyOwned;
  final int costCharged;
  final int totalCoins;
  final DateTime unlockedAt;
  final DateTime profileUpdatedAt;
  factory SkinUnlock.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['already_owned'] is! bool) {
      throw const FormatException('Invalid unlock response.');
    }
    final charged = JsonFields.nonNegativeInt(value, 'cost_charged');
    if (value['already_owned'] == true && charged != 0) {
      throw const FormatException('Invalid charge.');
    }
    return SkinUnlock(
      skinId: JsonFields.text(value, 'skin_id'),
      alreadyOwned: value['already_owned'] as bool,
      costCharged: charged,
      totalCoins: JsonFields.nonNegativeInt(value, 'new_total_coins'),
      unlockedAt: JsonFields.timestamp(value, 'unlocked_at'),
      profileUpdatedAt: JsonFields.timestamp(value, 'profile_updated_at'),
    );
  }
}

class SkinSelection {
  const SkinSelection(this.skinId, this.profileUpdatedAt);
  final String skinId;
  final DateTime profileUpdatedAt;
  factory SkinSelection.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid selection.');
    }
    return SkinSelection(
      JsonFields.text(value, 'selected_skin'),
      JsonFields.timestamp(value, 'profile_updated_at'),
    );
  }
}
