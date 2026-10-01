import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthIdentity {
  const AuthIdentity({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.isAnonymous = false,
  });
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool isAnonymous;
}

abstract class AuthService {
  AuthIdentity? get currentUser;
  Stream<void> get changes;
  Future<void> restoreSession();
  Future<void> signInAnonymously();
  Future<bool> linkGoogleIdentity();
  Future<void> signOut();
}

String oauthRedirect({required bool isWeb, required Uri base}) =>
    isWeb ? '${base.origin}/' : 'com.azitechstudio.skyhopper://login-callback/';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;
  Session? get currentSession => client.auth.currentSession;

  @override
  AuthIdentity? get currentUser {
    final session = currentSession;
    if (session == null || session.isExpired) return null;
    final authUser = session.user;
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    Map<String, dynamic>? googleData;
    for (final identity in authUser.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') {
        googleData = identity.identityData;
        break;
      }
    }
    return AuthIdentity(
      id: authUser.id,
      email: authUser.email,
      displayName:
          _metadataText(metadata, 'full_name') ??
          _metadataText(metadata, 'name') ??
          _metadataText(googleData, 'full_name') ??
          _metadataText(googleData, 'name'),
      avatarUrl:
          _metadataText(metadata, 'avatar_url') ??
          _metadataText(metadata, 'picture') ??
          _metadataText(googleData, 'avatar_url') ??
          _metadataText(googleData, 'picture'),
      isAnonymous: authUser.isAnonymous,
    );
  }

  @override
  Stream<void> get changes => client.auth.onAuthStateChange.map((_) {});

  @override
  Future<void> restoreSession() async {
    if (currentSession?.isExpired ?? false) {
      await client.auth.refreshSession().timeout(const Duration(seconds: 15));
    }
  }

  @override
  Future<void> signInAnonymously() async {
    await client.auth.signInAnonymously();
  }

  @override
  Future<bool> linkGoogleIdentity() => client.auth.linkIdentity(
    OAuthProvider.google,
    redirectTo: oauthRedirect(isWeb: kIsWeb, base: Uri.base),
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );

  @override
  Future<void> signOut() => client.auth.signOut();
}

String? _metadataText(Map<String, dynamic>? values, String key) {
  final value = values?[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
