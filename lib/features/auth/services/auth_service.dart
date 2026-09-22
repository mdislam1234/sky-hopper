import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthIdentity {
  const AuthIdentity({required this.id, this.email});
  final String id;
  final String? email;
}

abstract class AuthService {
  AuthIdentity? get currentUser;
  Stream<void> get changes;
  Future<void> restoreSession();
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}

String oauthRedirect({required bool isWeb, required Uri base}) =>
    isWeb ? '${base.origin}/' : 'com.skyhopper.game://login-callback/';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;
  Session? get currentSession => client.auth.currentSession;

  @override
  AuthIdentity? get currentUser {
    final session = currentSession;
    if (session == null || session.isExpired) return null;
    return AuthIdentity(id: session.user.id, email: session.user.email);
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
  Future<bool> signInWithGoogle() => client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: oauthRedirect(isWeb: kIsWeb, base: Uri.base),
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );

  @override
  Future<void> signOut() => client.auth.signOut();
}
