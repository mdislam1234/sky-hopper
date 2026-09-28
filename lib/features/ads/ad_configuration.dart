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
    final rewarded = kDebugMode ? androidTestRewardedId : configuredRewarded;
    final interstitial = kDebugMode
        ? androidTestInterstitialId
        : configuredInterstitial;
    final hasIds = rewarded.isNotEmpty && interstitial.isNotEmpty;
    final releaseUsesTestIds =
        !kDebugMode &&
        (rewarded == androidTestRewardedId ||
            interstitial == androidTestInterstitialId);
    return AdConfiguration(
      rewardedAdUnitId: rewarded,
      interstitialAdUnitId: interstitial,
      enabled: hasIds && !releaseUsesTestIds,
    );
  }
}
