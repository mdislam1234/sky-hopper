typedef RefreshConsent = Future<bool> Function();
typedef RequestConsentUpdate = Future<bool> Function();
typedef LoadConsentForm = Future<void> Function();
typedef StartAds = Future<void> Function();
typedef MarkAdsUnavailable = void Function();

/// Keeps the UMP startup order explicit and independently testable.
class AdConsentFlow {
  const AdConsentFlow();

  Future<void> run({
    required RefreshConsent refreshConsent,
    required RequestConsentUpdate requestConsentUpdate,
    required LoadConsentForm loadConsentForm,
    required StartAds startAds,
    required MarkAdsUnavailable markUnavailable,
  }) async {
    if (await refreshConsent()) {
      await startAds();
    }

    final updateSucceeded = await requestConsentUpdate();
    if (updateSucceeded) {
      await loadConsentForm();
    }

    if (await refreshConsent()) {
      await startAds();
    } else {
      markUnavailable();
    }
  }
}
