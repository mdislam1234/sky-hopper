import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AccountDeletionStore {
  Future<bool> isAwaitingGuestContinuation();
  Future<void> markAwaitingGuestContinuation();
  Future<void> clearAwaitingGuestContinuation();
}

class SharedPreferencesAccountDeletionStore implements AccountDeletionStore {
  SharedPreferencesAccountDeletionStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _pendingKey = 'sky_hopper.account_deleted';
  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isAwaitingGuestContinuation() async =>
      await _preferences.getBool(_pendingKey) ?? false;

  @override
  Future<void> markAwaitingGuestContinuation() =>
      _preferences.setBool(_pendingKey, true);

  @override
  Future<void> clearAwaitingGuestContinuation() =>
      _preferences.remove(_pendingKey);
}

class MemoryAccountDeletionStore implements AccountDeletionStore {
  MemoryAccountDeletionStore({this.awaitingGuestContinuation = false});

  bool awaitingGuestContinuation;

  @override
  Future<bool> isAwaitingGuestContinuation() async => awaitingGuestContinuation;

  @override
  Future<void> markAwaitingGuestContinuation() async {
    awaitingGuestContinuation = true;
  }

  @override
  Future<void> clearAwaitingGuestContinuation() async {
    awaitingGuestContinuation = false;
  }
}
