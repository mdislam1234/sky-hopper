import 'package:flutter/foundation.dart';

enum RewardedAdOutcome { earned, dismissed, unavailable, failed }

abstract class AdService extends ChangeNotifier {
  bool get canRequestAds;
  bool get privacyOptionsRequired;
  bool get rewardedReady;
  bool get interstitialReady;

  Future<void> initialize();
  Future<RewardedAdOutcome> showRewarded();
  Future<bool> showInterstitial();
  Future<bool> showPrivacyOptions();
}

class NoopAdService extends AdService {
  @override
  bool get canRequestAds => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  bool get rewardedReady => false;

  @override
  bool get interstitialReady => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<RewardedAdOutcome> showRewarded() async =>
      RewardedAdOutcome.unavailable;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showPrivacyOptions() async => false;
}
