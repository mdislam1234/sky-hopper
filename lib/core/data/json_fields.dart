abstract final class JsonFields {
  static String text(
    Map<String, dynamic> json,
    String key, {
    String? fallback,
  }) {
    final value = json[key] ?? fallback;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('Invalid $key.');
  }

  static int nonNegativeInt(
    Map<String, dynamic> json,
    String key, {
    int? fallback,
  }) {
    final value = json[key] ?? fallback;
    if (value is! int || value < 0 || value > 2147483647) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static DateTime timestamp(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid $key.');
    return parsed.toUtc();
  }
}
