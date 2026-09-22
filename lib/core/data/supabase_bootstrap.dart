import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

Future<SupabaseClient?> initializeSupabase({
  SupabaseConfig config = const SupabaseConfig.fromEnvironment(),
}) async {
  config.validate();
  if (config.isAbsent) {
    debugPrint(
      'Supabase is disabled: running the Sky Hopper UI without backend configuration.',
    );
    return null;
  }
  try {
    final supabase = await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
    return supabase.client;
  } on Exception {
    // The SDK marks itself initialized before local auth storage finishes.
    // Clean up a partial attempt so the startup Retry can initialize correctly.
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // There may be no initialized singleton to dispose.
    }
    // Never print configuration, tokens, or underlying SDK error payloads.
    throw StateError(
      'Supabase initialization failed. Check configuration and connectivity.',
    );
  }
}
