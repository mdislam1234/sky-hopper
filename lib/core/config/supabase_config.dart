class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final String url;
  final String publishableKey;
  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
  bool get isAbsent => url.isEmpty && publishableKey.isEmpty;

  void validate() {
    if (isAbsent) return;
    if (!isConfigured) {
      throw const FormatException(
        'Supply both Supabase Dart defines, or omit both for UI-only mode.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'SUPABASE_URL must be an HTTPS project origin.',
      );
    }
    // This phase accepts only the new public client key format, never privileged keys or JWTs.
    if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(publishableKey)) {
      throw const FormatException(
        'SUPABASE_PUBLISHABLE_KEY must be a publishable client key.',
      );
    }
  }
}
