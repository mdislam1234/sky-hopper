import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_configuration.dart';
import 'ad_consent_flow.dart';
import 'ad_service.dart';

class GoogleMobileAdsService extends AdService {
  GoogleMobileAdsService({AdConfiguration? configuration})
    : _configuration = configuration ?? AdConfiguration.fromEnvironment();

  final AdConfiguration _configuration;
  final AdConsentFlow _consentFlow = const AdConsentFlow();
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _initialized = false;
  bool _mobileAdsStarted = false;
  bool _loadingRewarded = false;
  bool _loadingInterstitial = false;
  bool _disposed = false;
  RewardedAdState _rewardedState = RewardedAdState.checkingConsent;

  @override
  bool get canRequestAds => _canRequestAds && _configuration.enabled;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  bool get rewardedReady =>
      canRequestAds &&
      _rewardedState == RewardedAdState.ready &&
      _rewarded != null;

  @override
  RewardedAdState get rewardedState => _rewardedState;

  @override
  bool get interstitialReady => canRequestAds && _interstitial != null;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _setRewardedState(RewardedAdState.checkingConsent);
    await _consentFlow.run(
      refreshConsent: _refreshConsentState,
      requestConsentUpdate: _requestConsentUpdate,
      loadConsentForm: _loadConsentFormIfRequired,
      startAds: _startAdsIfAllowed,
      markUnavailable: _markAdsUnavailable,
    );
  }

  Future<bool> _requestConsentUpdate() async {
    if (_disposed) return false;
    final update = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        _debugAds('consent info update succeeded');
        update.complete(true);
      },
      (_) {
        _debugAds('consent info update failed');
        update.complete(false);
      },
    );
    return update.future;
  }

  Future<void> _loadConsentFormIfRequired() async {
    if (_disposed) return;
    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        _debugAds(
          error == null
              ? 'consent form flow completed'
              : 'consent form flow failed',
        );
      });
    } catch (_) {
      _debugAds('consent form flow threw an exception');
    }
  }

  Future<bool> _refreshConsentState() async {
    if (_disposed) return false;
    try {
      final nextCanRequest = await ConsentInformation.instance.canRequestAds();
      final consentStatus = await ConsentInformation.instance
          .getConsentStatus();
      final privacyStatus = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      if (_disposed) return false;
      _canRequestAds = nextCanRequest;
      _privacyOptionsRequired =
          privacyStatus == PrivacyOptionsRequirementStatus.required;
      _debugAds(
        'consent status=${consentStatus.name} '
        'canRequestAds=$nextCanRequest '
        'privacyOptionsRequired=$_privacyOptionsRequired',
      );
      notifyListeners();
      return canRequestAds;
    } catch (_) {
      _debugAds('consent state refresh failed');
      return canRequestAds;
    }
  }

  Future<void> _startAdsIfAllowed() async {
    if (!canRequestAds || _disposed) return;
    if (!_mobileAdsStarted) {
      _mobileAdsStarted = true;
      try {
        await MobileAds.instance.initialize();
        _debugAds('Mobile Ads initialized');
      } catch (_) {
        _mobileAdsStarted = false;
        _debugAds('Mobile Ads initialization failed');
        _setRewardedState(RewardedAdState.unavailable);
        return;
      }
    }
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    if (!canRequestAds || _disposed || _loadingRewarded || _rewarded != null) {
      return;
    }
    _loadingRewarded = true;
    _setRewardedState(RewardedAdState.loading);
    _debugAds('rewarded load requested');
    try {
      RewardedAd.load(
        adUnitId: _configuration.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingRewarded = false;
            if (_disposed) {
              ad.dispose();
              return;
            }
            _rewarded = ad;
            _debugAds('rewarded load succeeded');
            _setRewardedState(RewardedAdState.ready);
          },
          onAdFailedToLoad: (error) {
            _loadingRewarded = false;
            _debugAds('rewarded load failed code=${error.code}');
            if (!_disposed) {
              _setRewardedState(RewardedAdState.unavailable);
            }
          },
        ),
      );
    } catch (_) {
      _loadingRewarded = false;
      _debugAds('rewarded load threw an exception');
      if (!_disposed) _setRewardedState(RewardedAdState.unavailable);
    }
  }

  void _loadInterstitial() {
    if (!canRequestAds ||
        _disposed ||
        _loadingInterstitial ||
        _interstitial != null) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _configuration.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
          if (!_disposed) notifyListeners();
        },
      ),
    );
  }

  @override
  Future<void> retryRewarded() async {
    if (_disposed ||
        _rewardedState == RewardedAdState.ready ||
        _loadingRewarded) {
      return;
    }
    _setRewardedState(RewardedAdState.checkingConsent);
    if (!await _refreshConsentState()) {
      _setRewardedState(RewardedAdState.unavailable);
      return;
    }
    await _startAdsIfAllowed();
  }

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    final ad = _rewarded;
    if (!canRequestAds || ad == null || _disposed) {
      return RewardedAdOutcome.unavailable;
    }
    _rewarded = null;
    _setRewardedState(RewardedAdState.loading);
    final result = Completer<RewardedAdOutcome>();
    var earned = false;
    void finish(RewardedAdOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdImpression: (_) => _debugAds('rewarded impression recorded'),
      onAdDismissedFullScreenContent: (shownAd) {
        _debugAds('rewarded dismissed earned=$earned');
        shownAd.dispose();
        finish(earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        _debugAds('rewarded show failed code=${error.code}');
        failedAd.dispose();
        finish(RewardedAdOutcome.failed);
        _loadRewarded();
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, _) {
          if (!earned) {
            earned = true;
            _debugAds('rewarded earned callback received');
          }
        },
      );
    } catch (_) {
      _debugAds('rewarded show threw an exception');
      ad.dispose();
      finish(RewardedAdOutcome.failed);
      _loadRewarded();
    }
    return result.future;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (!canRequestAds || ad == null || _disposed) return false;
    _interstitial = null;
    notifyListeners();
    final result = Completer<bool>();
    void finish(bool shown) {
      if (!result.isCompleted) result.complete(shown);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdImpression: (_) {},
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        finish(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        finish(false);
        _loadInterstitial();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      ad.dispose();
      finish(false);
      _loadInterstitial();
    }
    return result.future;
  }

  @override
  Future<bool> showPrivacyOptions() async {
    if (!_privacyOptionsRequired || _disposed) return false;
    final result = Completer<bool>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      result.complete(error == null);
    });
    final shown = await result.future;
    await _refreshConsentState();
    if (canRequestAds) {
      await _startAdsIfAllowed();
    } else {
      _markAdsUnavailable();
    }
    return shown;
  }

  void _markAdsUnavailable() {
    if (_disposed) return;
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
    _loadingRewarded = false;
    _loadingInterstitial = false;
    _setRewardedState(RewardedAdState.unavailable);
  }

  void _setRewardedState(RewardedAdState value) {
    if (_rewardedState == value || _disposed) return;
    _rewardedState = value;
    _debugAds('rewarded readiness=${value.name}');
    notifyListeners();
  }

  void _debugAds(String message) {
    if (kDebugMode) debugPrint('[Ads] $message');
  }

  @override
  void dispose() {
    _disposed = true;
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
    super.dispose();
  }
}
