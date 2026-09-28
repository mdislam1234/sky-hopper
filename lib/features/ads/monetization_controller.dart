import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ad_service.dart';

class MonetizationController extends ChangeNotifier {
  MonetizationController(
    this._service, {
    DateTime Function()? now,
    this.interstitialFrequency = 3,
    this.interstitialCooldown = const Duration(minutes: 2),
  }) : _now = now ?? DateTime.now {
    _service.addListener(_serviceChanged);
  }

  final AdService _service;
  final DateTime Function() _now;
  final int interstitialFrequency;
  final Duration interstitialCooldown;
  final Set<String> _countedRunIds = {};
  int _normalRunsSaved = 0;
  bool _interstitialPending = false;
  bool _fullscreenBusy = false;
  bool _initialized = false;
  DateTime? _lastFullscreenAt;

  bool get rewardedAvailable =>
      !_fullscreenBusy && _service.canRequestAds && _service.rewardedReady;
  RewardedAdState get rewardedState => _service.rewardedState;
  bool get privacyOptionsRequired => _service.privacyOptionsRequired;
  bool get fullscreenBusy => _fullscreenBusy;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _service.initialize();
  }

  bool canOfferRewarded({
    required bool isNormalMode,
    required bool runSaved,
    required int coinsCollected,
    required bool alreadyConsumed,
  }) =>
      isNormalMode &&
      runSaved &&
      coinsCollected > 0 &&
      !alreadyConsumed &&
      rewardedAvailable;

  bool isRewardedRunEligible({
    required bool isNormalMode,
    required bool runSaved,
    required int coinsCollected,
    required bool alreadyConsumed,
  }) => isNormalMode && runSaved && coinsCollected > 0 && !alreadyConsumed;

  Future<void> retryRewarded() async {
    if (_fullscreenBusy) return;
    await _service.retryRewarded();
  }

  void recordCompletedRun(String runId, {required bool isNormalMode}) {
    if (!isNormalMode) return;
    if (!_countedRunIds.add(runId)) return;
    _normalRunsSaved++;
    if (_normalRunsSaved > 1 && _normalRunsSaved % interstitialFrequency == 0) {
      _interstitialPending = true;
    }
    notifyListeners();
  }

  Future<RewardedAdOutcome> showRewarded() async {
    if (!rewardedAvailable) return RewardedAdOutcome.unavailable;
    _fullscreenBusy = true;
    notifyListeners();
    try {
      final outcome = await _service.showRewarded();
      if (outcome == RewardedAdOutcome.earned ||
          outcome == RewardedAdOutcome.dismissed) {
        _lastFullscreenAt = _now();
        _interstitialPending = false;
      }
      return outcome;
    } finally {
      _fullscreenBusy = false;
      notifyListeners();
    }
  }

  Future<bool> showInterstitialAtBreak() async {
    if (_fullscreenBusy || !_interstitialPending) return false;
    final last = _lastFullscreenAt;
    if (last != null && _now().difference(last) < interstitialCooldown) {
      return false;
    }
    if (!_service.canRequestAds || !_service.interstitialReady) return false;
    _fullscreenBusy = true;
    notifyListeners();
    try {
      final shown = await _service.showInterstitial();
      if (shown) {
        _interstitialPending = false;
        _lastFullscreenAt = _now();
      }
      return shown;
    } finally {
      _fullscreenBusy = false;
      notifyListeners();
    }
  }

  Future<bool> showPrivacyOptions() => _service.showPrivacyOptions();

  void _serviceChanged() => notifyListeners();

  @override
  void dispose() {
    _service.removeListener(_serviceChanged);
    _service.dispose();
    super.dispose();
  }
}
