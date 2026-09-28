import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_configuration.dart';
import 'ad_service.dart';

class GoogleMobileAdsService extends AdService {
  GoogleMobileAdsService({AdConfiguration? configuration})
    : _configuration = configuration ?? AdConfiguration.fromEnvironment();

  final AdConfiguration _configuration;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _initialized = false;
  bool _mobileAdsStarted = false;
  bool _loadingRewarded = false;
  bool _loadingInterstitial = false;
  bool _disposed = false;

  @override
  bool get canRequestAds => _canRequestAds && _configuration.enabled;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  bool get rewardedReady => canRequestAds && _rewarded != null;

  @override
  bool get interstitialReady => canRequestAds && _interstitial != null;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await _refreshConsentState();
    await _startAdsIfAllowed();

    final update = Completer<void>();
    var updateSucceeded = false;
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        updateSucceeded = true;
        update.complete();
      },
      (_) => update.complete(),
    );
    await update.future;
    if (_disposed) return;
    if (updateSucceeded) {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    }
    await _refreshConsentState();
    await _startAdsIfAllowed();
  }

  Future<void> _refreshConsentState() async {
    if (_disposed) return;
    try {
      final nextCanRequest = await ConsentInformation.instance.canRequestAds();
      final privacyStatus = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      if (_disposed) return;
      _canRequestAds = nextCanRequest;
      _privacyOptionsRequired =
          privacyStatus == PrivacyOptionsRequirementStatus.required;
      notifyListeners();
    } catch (_) {
      // Consent or network failure keeps ads unavailable for this session.
    }
  }

  Future<void> _startAdsIfAllowed() async {
    if (!canRequestAds || _disposed) return;
    if (!_mobileAdsStarted) {
      _mobileAdsStarted = true;
      try {
        await MobileAds.instance.initialize();
      } catch (_) {
        _mobileAdsStarted = false;
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
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          if (!_disposed) notifyListeners();
        },
      ),
    );
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
  Future<RewardedAdOutcome> showRewarded() async {
    final ad = _rewarded;
    if (!canRequestAds || ad == null || _disposed) {
      return RewardedAdOutcome.unavailable;
    }
    _rewarded = null;
    notifyListeners();
    final result = Completer<RewardedAdOutcome>();
    var earned = false;
    void finish(RewardedAdOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdImpression: (_) {},
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        finish(earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        finish(RewardedAdOutcome.failed);
        _loadRewarded();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
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
    await _startAdsIfAllowed();
    return shown;
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
