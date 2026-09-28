import 'ad_service.dart';

class RewardedOfferPresentation {
  const RewardedOfferPresentation._({
    required this.visible,
    required this.enabled,
    required this.loading,
    required this.retryable,
    this.label,
  });

  const RewardedOfferPresentation.hidden()
    : this._(visible: false, enabled: false, loading: false, retryable: false);

  final bool visible;
  final bool enabled;
  final bool loading;
  final bool retryable;
  final String? label;

  static RewardedOfferPresentation resolve({
    required bool eligible,
    required bool claimPending,
    required bool busy,
    required RewardedAdState adState,
    required int estimatedBonus,
  }) {
    if (claimPending) {
      return RewardedOfferPresentation._(
        visible: true,
        enabled: !busy,
        loading: busy,
        retryable: false,
        label: 'CLAIM BONUS',
      );
    }
    if (!eligible || adState == RewardedAdState.unsupported) {
      return const RewardedOfferPresentation.hidden();
    }

    return switch (adState) {
      RewardedAdState.checkingConsent => const RewardedOfferPresentation._(
        visible: true,
        enabled: false,
        loading: true,
        retryable: false,
        label: 'CHECKING REWARD VIDEO…',
      ),
      RewardedAdState.loading => const RewardedOfferPresentation._(
        visible: true,
        enabled: false,
        loading: true,
        retryable: false,
        label: 'LOADING REWARD VIDEO…',
      ),
      RewardedAdState.ready => RewardedOfferPresentation._(
        visible: true,
        enabled: !busy,
        loading: busy,
        retryable: false,
        label: 'WATCH VIDEO · +$estimatedBonus COINS',
      ),
      RewardedAdState.unavailable => const RewardedOfferPresentation._(
        visible: true,
        enabled: false,
        loading: false,
        retryable: true,
        label: 'VIDEO UNAVAILABLE',
      ),
      RewardedAdState.unsupported => const RewardedOfferPresentation.hidden(),
    };
  }
}
