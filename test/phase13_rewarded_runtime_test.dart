import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/ads/ad_consent_flow.dart';
import 'package:sky_hopper/features/ads/ad_service.dart';
import 'package:sky_hopper/features/ads/monetization_controller.dart';
import 'package:sky_hopper/features/ads/rewarded_bonus_claim.dart';
import 'package:sky_hopper/features/ads/rewarded_offer.dart';
import 'package:sky_hopper/features/game/systems/run_save_controller.dart';
import 'package:sky_hopper/features/game/widgets/game_over_overlay.dart';

class _RuntimeFakeAdService extends AdService {
  _RuntimeFakeAdService({this.state = RewardedAdState.loading});

  RewardedAdState state;
  int retryCalls = 0;
  int showCalls = 0;

  @override
  bool get canRequestAds => true;

  @override
  bool get privacyOptionsRequired => false;

  @override
  bool get rewardedReady => state == RewardedAdState.ready;

  @override
  RewardedAdState get rewardedState => state;

  @override
  bool get interstitialReady => false;

  void transitionTo(RewardedAdState value) {
    state = value;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> retryRewarded() async {
    retryCalls++;
    transitionTo(RewardedAdState.loading);
  }

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    showCalls++;
    return RewardedAdOutcome.earned;
  }

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showPrivacyOptions() async => false;
}

class _RewardOfferHarness extends StatelessWidget {
  const _RewardOfferHarness({
    required this.controller,
    this.isNormalMode = true,
    this.alreadyConsumed = false,
  });

  final MonetizationController controller;
  final bool isNormalMode;
  final bool alreadyConsumed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final eligible = controller.isRewardedRunEligible(
          isNormalMode: isNormalMode,
          runSaved: true,
          coinsCollected: 8,
          alreadyConsumed: alreadyConsumed,
        );
        final offer = RewardedOfferPresentation.resolve(
          eligible: eligible,
          claimPending: false,
          busy: false,
          adState: controller.rewardedState,
          estimatedBonus: 4,
        );
        return GameOverOverlay(
          score: 100,
          coins: 8,
          paused: false,
          savePhase: SavePhase.saved,
          rewardActionLabel: offer.label,
          rewardActionEnabled: offer.enabled,
          rewardLoading: offer.loading,
          onRewardRetry: offer.retryable
              ? () => controller.retryRewarded()
              : null,
          onReward: () {},
          onContinue: () {},
          onHome: () {},
        );
      },
    ),
  );
}

void main() {
  group('rewarded runtime offer', () {
    testWidgets('saved normal run shows a disabled loading state', (
      tester,
    ) async {
      final service = _RuntimeFakeAdService();
      final controller = MonetizationController(service);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_RewardOfferHarness(controller: controller));

      expect(find.text('LOADING REWARD VIDEO…'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('load completion after Game Over enables the offer', (
      tester,
    ) async {
      final service = _RuntimeFakeAdService();
      final controller = MonetizationController(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_RewardOfferHarness(controller: controller));

      service.transitionTo(RewardedAdState.ready);
      await tester.pump();

      expect(find.text('WATCH VIDEO · +4 COINS'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('load failure exposes an unavailable state and retry', (
      tester,
    ) async {
      final service = _RuntimeFakeAdService(state: RewardedAdState.unavailable);
      final controller = MonetizationController(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_RewardOfferHarness(controller: controller));

      expect(find.text('VIDEO UNAVAILABLE'), findsOneWidget);
      expect(find.text('RETRY VIDEO'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('RETRY VIDEO'));
      await tester.pump();
      expect(service.retryCalls, 1);
      expect(find.text('LOADING REWARD VIDEO…'), findsOneWidget);
    });

    testWidgets('Daily Challenge does not offer a rewarded video', (
      tester,
    ) async {
      final service = _RuntimeFakeAdService(state: RewardedAdState.ready);
      final controller = MonetizationController(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _RewardOfferHarness(controller: controller, isNormalMode: false),
      );

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('VIDEO'), findsNothing);
    });

    testWidgets('an already consumed offer remains hidden', (tester) async {
      final service = _RuntimeFakeAdService(state: RewardedAdState.ready);
      final controller = MonetizationController(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _RewardOfferHarness(controller: controller, alreadyConsumed: true),
      );

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('VIDEO'), findsNothing);
    });
  });

  group('UMP startup ordering', () {
    test('canRequestAds false never starts an ad load prematurely', () async {
      var starts = 0;
      var forms = 0;
      var unavailable = 0;

      await const AdConsentFlow().run(
        refreshConsent: () async => false,
        requestConsentUpdate: () async => false,
        loadConsentForm: () async => forms++,
        startAds: () async => starts++,
        markUnavailable: () => unavailable++,
      );

      expect(starts, 0);
      expect(forms, 0);
      expect(unavailable, 1);
    });

    test('a false-to-true consent change starts loading after UMP', () async {
      final events = <String>[];
      final consentResults = <bool>[false, true].iterator;

      await const AdConsentFlow().run(
        refreshConsent: () async {
          consentResults.moveNext();
          events.add('refresh:${consentResults.current}');
          return consentResults.current;
        },
        requestConsentUpdate: () async {
          events.add('update');
          return true;
        },
        loadConsentForm: () async => events.add('form'),
        startAds: () async => events.add('start'),
        markUnavailable: () => events.add('unavailable'),
      );

      expect(events, [
        'refresh:false',
        'update',
        'form',
        'refresh:true',
        'start',
      ]);
    });

    test('cached consent starts ads despite an update failure', () async {
      var started = false;
      var loadRequests = 0;
      var forms = 0;

      await const AdConsentFlow().run(
        refreshConsent: () async => true,
        requestConsentUpdate: () async => false,
        loadConsentForm: () async => forms++,
        startAds: () async {
          if (!started) {
            started = true;
            loadRequests++;
          }
        },
        markUnavailable: () {},
      );

      expect(loadRequests, 1);
      expect(forms, 0);
    });
  });

  test('an earned callback can begin only one claim', () {
    final gate = RewardedClaimGate();
    var claimCalls = 0;

    if (gate.tryStart()) claimCalls++;
    if (gate.tryStart()) claimCalls++;
    gate.complete();
    if (gate.tryStart()) claimCalls++;

    expect(claimCalls, 1);
    expect(gate.completed, isTrue);
  });
}
