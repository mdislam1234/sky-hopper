import 'package:flutter/foundation.dart';

class AdConfiguration {
  const AdConfiguration({
    required this.rewardedAdUnitId,
    required this.interstitialAdUnitId,
    required this.enabled,
  });

  static const androidTestRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _googleSamplePublisherId = '3940256099942544';
  static final _adUnitPattern = RegExp(r'^ca-app-pub-([0-9]{16})/[0-9]{10}$');

  final String rewardedAdUnitId;
  final String interstitialAdUnitId;
  final bool enabled;

  factory AdConfiguration.fromEnvironment() {
    const configuredRewarded = String.fromEnvironment(
      'ADMOB_REWARDED_AD_UNIT_ID',
    );
    const configuredInterstitial = String.fromEnvironment(
      'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    );
    final useTestIds = !kReleaseMode;
    final rewarded = useTestIds ? androidTestRewardedId : configuredRewarded;
    final interstitial = useTestIds
        ? androidTestInterstitialId
        : configuredInterstitial;
    return AdConfiguration(
      rewardedAdUnitId: rewarded,
      interstitialAdUnitId: interstitial,
      enabled:
          useTestIds ||
          (isProductionAdUnitId(rewarded) &&
              isProductionAdUnitId(interstitial) &&
              publisherIdFor(rewarded) == publisherIdFor(interstitial)),
    );
  }

  static bool isProductionAdUnitId(String value) {
    final match = _adUnitPattern.firstMatch(value);
    return match != null && match.group(1) != _googleSamplePublisherId;
  }

  static String? publisherIdFor(String value) =>
      _adUnitPattern.firstMatch(value)?.group(1);
}
