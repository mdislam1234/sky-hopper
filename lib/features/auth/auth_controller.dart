import 'dart:async';

import 'package:flutter/foundation.dart';

import '../profile/models/profile.dart';
import '../../core/data/data_exception.dart';
import '../game/models/game_result.dart';
import '../skins/data/skin_repository.dart';
import '../skins/models/skin.dart';
import 'services/auth_service.dart';

enum AuthStage {
  resolving,
  signedOut,
  loadingProfile,
  ready,
  profileError,
  sessionError,
  unconfigured,
}

class AuthController extends ChangeNotifier {
  AuthController({
    this.service,
    this.loadProfile,
    this.skinStore,
    this.offlinePreview = false,
  });
  final AuthService? service;
  final Future<Profile?> Function()? loadProfile;
  final bool offlinePreview;
  final SkinStore? skinStore;
  List<Skin> catalog = const [];
  int _profileReadGeneration = 0;
  SkinAppearance get selectedAppearance {
    for (final skin in catalog) {
      if (skin.id == profile?.selectedSkin) return skin.appearance;
    }
    return SkinAppearance.defaultSkin;
  }

  AuthStage stage = AuthStage.resolving;
  AuthIdentity? user;
  Profile? profile;
  String? message;
  bool signingIn = false;
  bool signingOut = false;
  bool _started = false;
  bool _disposed = false;
  bool _restoring = false;
  int _generation = 0;
  int _loginAttempt = 0;
  StreamSubscription<void>? _subscription;
  Timer? _loginTimer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (service == null) {
      stage = offlinePreview ? AuthStage.ready : AuthStage.unconfigured;
      _notify();
      return;
    }
    _subscription = service!.changes.listen(
      (_) {
        if (!_restoring) _resolve();
      },
      onError: (Object error) {
        if (_disposed) return;
        signingIn = false;
        _loginTimer?.cancel();
        message = 'Sign-in could not be completed. Please try again.';
        _resolve();
      },
    );
    await retrySession();
  }

  Future<void> retrySession() async {
    _restoring = true;
    stage = AuthStage.resolving;
    message = null;
    _notify();
    try {
      await service!.restoreSession().timeout(const Duration(seconds: 20));
      _restoring = false;
      if (!_disposed) await _resolve();
    } catch (_) {
      _restoring = false;
      if (_disposed || stage == AuthStage.ready) return;
      _generation++;
      user = null;
      profile = null;
      stage = AuthStage.sessionError;
      message =
          'Unable to restore your session. Check your connection and retry.';
      _notify();
    }
  }

  Future<void> _resolve({bool force = false}) async {
    if (_disposed) return;
    final next = service!.currentUser;
    if (!force &&
        next?.id == user?.id &&
        (stage == AuthStage.ready || stage == AuthStage.loadingProfile)) {
      return;
    }
    final generation = ++_generation;
    user = next;
    profile = null;
    catalog = const [];
    _profileReadGeneration++;
    signingIn = false;
    _loginAttempt++;
    _loginTimer?.cancel();
    if (next == null) {
      stage = AuthStage.signedOut;
      _notify();
      return;
    }
    message = null;
    stage = AuthStage.loadingProfile;
    _notify();
    try {
      final loaded = await loadProfile!().timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) return;
      if (loaded == null || loaded.id != next.id) {
        stage = AuthStage.profileError;
        message = 'Your profile is not available yet. Retry or sign out and contact support.';
      } else {
        profile = loaded;
        stage = AuthStage.ready;
        await _loadCatalog(next.id, generation);
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      stage = AuthStage.profileError;
      message =
          'Your profile could not be loaded. Check your connection and retry.';
    }
    _notify();
  }

  Future<void> retryProfile() => _resolve(force: true);

  bool isCurrentOwner(String owner) =>
      !_disposed &&
      stage == AuthStage.ready &&
      user?.id == owner &&
      service?.currentUser?.id == owner &&
      profile?.id == owner;

  void requireOwner(String owner) {
    if (!isCurrentOwner(owner)) {
      throw const DataException(DataError.unauthenticated);
    }
  }

  Future<void> _loadCatalog(String owner, int generation) async {
    if (skinStore == null) return;
    try {
      final loaded = await skinStore!.fetchCatalog().timeout(
        const Duration(seconds: 15),
      );
      if (isCurrentOwner(owner) && generation == _generation) {
        catalog = loaded;
        _notify();
      }
    } catch (_) {
      // Gameplay can always use the original appearance while catalog is offline.
    }
  }

  void cacheCatalog(String owner, List<Skin> loaded) {
    requireOwner(owner);
    catalog = List.unmodifiable(loaded);
    _notify();
  }

  /// A fresh server read handles balances that can now both increase and decrease.
  /// Only the latest requested read may publish; never take max(balance).
  Future<void> refreshConfirmedProfile(String owner) async {
    if (!isCurrentOwner(owner) || loadProfile == null) return;
    final generation = ++_profileReadGeneration;
    final sessionGeneration = _generation;
    try {
      final loaded = await loadProfile!().timeout(const Duration(seconds: 15));
      if (!isCurrentOwner(owner) ||
          generation != _profileReadGeneration ||
          sessionGeneration != _generation) {
        return;
      }
      if (loaded == null || loaded.id != owner) {
        throw const FormatException('Missing profile.');
      }
      profile = loaded;
      message = null;
      _notify();
    } catch (_) {
      if (isCurrentOwner(owner) && generation == _profileReadGeneration) {
        message = 'Saved changes. Balance refresh is unavailable; reopen Skins to retry.';
        _notify();
      }
    }
  }

  Future<SkinUnlock> unlockSkinFor(String owner, String skinId) async {
    requireOwner(owner);
    final sessionGeneration = _generation;
    if (skinStore == null) throw const DataException(DataError.unavailable);
    final result = await skinStore!
        .unlockSkin(skinId)
        .timeout(const Duration(seconds: 15));
    if (isCurrentOwner(owner) && sessionGeneration == _generation) {
      // Confirmed charge only. Re-read after this and every save to reconcile
      // concurrent earnings, spending and responses from other devices.
      _profileReadGeneration++;
      final current = profile!;
      profile = Profile.fromJson({
        ...current.toJson(),
        'total_coins': result.totalCoins,
        'updated_at': result.profileUpdatedAt.toIso8601String(),
      });
      _notify();
      await refreshConfirmedProfile(owner);
    }
    return result;
  }

  Future<SkinSelection> selectSkinFor(String owner, String skinId) async {
    requireOwner(owner);
    final sessionGeneration = _generation;
    if (skinStore == null) throw const DataException(DataError.unavailable);
    final result = await skinStore!
        .selectSkin(skinId)
        .timeout(const Duration(seconds: 15));
    if (isCurrentOwner(owner) && sessionGeneration == _generation) {
      _profileReadGeneration++;
      profile = Profile.fromJson({
        ...profile!.toJson(),
        'selected_skin': result.skinId,
        'updated_at': result.profileUpdatedAt.toIso8601String(),
      });
      _notify();
      await refreshConfirmedProfile(owner);
    }
    return result;
  }

  /// Applies only a server-confirmed result for the same currently signed-in owner.
  /// Late responses may update Home after leaving the game, but never another user.
  Future<SavedGameResult> submitRunFor(
    String ownerId,
    GameResult result,
    SubmitGameResult? submit,
  ) async {
    if (_disposed ||
        stage != AuthStage.ready ||
        user?.id != ownerId ||
        service?.currentUser?.id != ownerId) {
      throw const DataException(DataError.unauthenticated);
    }
    if (submit == null) throw const DataException(DataError.unavailable);
    final sessionGeneration = _generation;
    final saved = await submit(result);
    saved.validateFor(result);
    if (skinStore != null) {
      // A delayed earning response must never restore a balance already spent.
      if (sessionGeneration == _generation) {
        await refreshConfirmedProfile(ownerId);
      }
      return saved;
    }
    final current = profile;
    if (!_disposed &&
        user?.id == ownerId &&
        service?.currentUser?.id == ownerId &&
        current?.id == ownerId) {
      // Phase 6 balances only increase. Concurrent responses must not roll back
      // a newer confirmed balance; no client-side coin award is calculated here.
      profile = Profile(
        id: current!.id,
        displayName: current.displayName,
        avatarUrl: current.avatarUrl,
        totalCoins: saved.totalCoins > current.totalCoins
            ? saved.totalCoins
            : current.totalCoins,
        selectedSkin: current.selectedSkin,
        createdAt: current.createdAt,
        updatedAt: saved.profileUpdatedAt.isAfter(current.updatedAt)
            ? saved.profileUpdatedAt
            : current.updatedAt,
      );
      _notify();
    }
    return saved;
  }

  Future<void> signIn() async {
    if (signingIn || service == null) return;
    signingIn = true;
    final attempt = ++_loginAttempt;
    message = null;
    _notify();
    // OAuth completion arrives via auth changes, not the browser-launch Future.
    _loginTimer = Timer(const Duration(seconds: 60), cancelPendingSignIn);
    try {
      final launched = await service!.signInWithGoogle().timeout(
        const Duration(seconds: 15),
      );
      if (!launched) throw StateError('Not launched');
    } catch (_) {
      if (_disposed || attempt != _loginAttempt) return;
      _loginTimer?.cancel();
      signingIn = false;
      message = 'Google sign-in could not open. Please try again.';
      _notify();
    }
  }

  void cancelPendingSignIn() {
    if (_disposed || !signingIn) return;
    _loginTimer?.cancel();
    _loginAttempt++;
    signingIn = false;
    message = 'Sign-in is not complete. You can try again.';
    _notify();
  }

  Future<void> signOut() async {
    if (signingOut || service == null) return;
    signingOut = true;
    message = null;
    _notify();
    try {
      await service!.signOut().timeout(const Duration(seconds: 15));
      if (_disposed) return;
      _generation++;
      _loginTimer?.cancel();
      user = null;
      profile = null;
      stage = AuthStage.signedOut;
      signingIn = false;
    } catch (_) {
      if (!_disposed) {
        message = 'Sign out failed. Please check your connection and retry.';
      }
    } finally {
      signingOut = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _loginTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
