import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/ads/ad_configuration.dart';
import 'package:sky_hopper/features/ads/ad_service.dart';
import 'package:sky_hopper/features/ads/monetization_controller.dart';
import 'package:sky_hopper/features/ads/rewarded_bonus_claim.dart';
import 'package:sky_hopper/features/game/systems/run_save_controller.dart';
import 'package:sky_hopper/features/game/widgets/game_over_overlay.dart';

class _FakeAdService extends AdService {
  bool permitted = true;
  bool privacyRequired = false;
  bool rewardReady = true;
  bool interstitialIsReady = true;
  RewardedAdOutcome rewardOutcome = RewardedAdOutcome.earned;
  bool interstitialOutcome = true;
  int initializeCalls = 0;
  int rewardCalls = 0;
  int rewardRetryCalls = 0;
  int interstitialCalls = 0;
  int privacyCalls = 0;

  @override
  bool get canRequestAds => permitted;

  @override
  bool get privacyOptionsRequired => privacyRequired;

  @override
  bool get rewardedReady => rewardReady;

  @override
  RewardedAdState get rewardedState => !permitted
      ? RewardedAdState.unavailable
      : rewardReady
      ? RewardedAdState.ready
      : RewardedAdState.loading;

  @override
  bool get interstitialReady => interstitialIsReady;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> retryRewarded() async => rewardRetryCalls++;

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    rewardCalls++;
    return rewardOutcome;
  }

  @override
  Future<bool> showInterstitial() async {
    interstitialCalls++;
    return interstitialOutcome;
  }

  @override
  Future<bool> showPrivacyOptions() async {
    privacyCalls++;
    return privacyRequired;
  }
}

void main() {
  group('Android monetization policy', () {
    test('no-op service never requests or displays ads', () async {
      final service = NoopAdService();
      await service.initialize();
      expect(service.canRequestAds, isFalse);
      expect(await service.showRewarded(), RewardedAdOutcome.unavailable);
      expect(await service.showInterstitial(), isFalse);
      expect(await service.showPrivacyOptions(), isFalse);
    });

    test('debug configuration uses only official Android sample IDs', () {
      final configuration = AdConfiguration.fromEnvironment();
      expect(
        configuration.rewardedAdUnitId,
        AdConfiguration.androidTestRewardedId,
      );
      expect(
        configuration.interstitialAdUnitId,
        AdConfiguration.androidTestInterstitialId,
      );
      expect(configuration.enabled, isTrue);
    });

    test('initialization is guarded against duplicate SDK startup', () async {
      final service = _FakeAdService();
      final controller = MonetizationController(service);
      await controller.initialize();
      await controller.initialize();
      expect(service.initializeCalls, 1);
    });

    test(
      'interstitial is never shown on first run and appears on third',
      () async {
        final service = _FakeAdService();
        final controller = MonetizationController(service);
        controller.recordCompletedRun('run-1', isNormalMode: true);
        expect(await controller.showInterstitialAtBreak(), isFalse);
        controller.recordCompletedRun('run-2', isNormalMode: true);
        expect(await controller.showInterstitialAtBreak(), isFalse);
        controller.recordCompletedRun('run-3', isNormalMode: true);
        expect(await controller.showInterstitialAtBreak(), isTrue);
        expect(service.interstitialCalls, 1);
      },
    );

    test('duplicate run IDs do not advance interstitial frequency', () async {
      final service = _FakeAdService();
      final controller = MonetizationController(service);
      controller.recordCompletedRun('run-1', isNormalMode: true);
      controller.recordCompletedRun('run-1', isNormalMode: true);
      controller.recordCompletedRun('run-2', isNormalMode: true);
      expect(await controller.showInterstitialAtBreak(), isFalse);
      controller.recordCompletedRun('run-3', isNormalMode: true);
      expect(await controller.showInterstitialAtBreak(), isTrue);
    });

    test(
      'rewarded display suppresses an immediately pending interstitial',
      () async {
        final service = _FakeAdService();
        final controller = MonetizationController(service);
        for (final id in ['run-1', 'run-2', 'run-3']) {
          controller.recordCompletedRun(id, isNormalMode: true);
        }
        expect(await controller.showRewarded(), RewardedAdOutcome.earned);
        expect(await controller.showInterstitialAtBreak(), isFalse);
        expect(service.rewardCalls, 1);
        expect(service.interstitialCalls, 0);
      },
    );

    test('cooldown prevents back-to-back interstitials', () async {
      var now = DateTime.utc(2026, 9, 28, 12);
      final service = _FakeAdService();
      final controller = MonetizationController(service, now: () => now);
      for (var index = 1; index <= 3; index++) {
        controller.recordCompletedRun('run-$index', isNormalMode: true);
      }
      expect(await controller.showInterstitialAtBreak(), isTrue);
      for (var index = 4; index <= 6; index++) {
        controller.recordCompletedRun('run-$index', isNormalMode: true);
      }
      expect(await controller.showInterstitialAtBreak(), isFalse);
      now = now.add(const Duration(minutes: 3));
      expect(await controller.showInterstitialAtBreak(), isTrue);
    });

    test(
      'privacy options are delegated only to the platform service',
      () async {
        final service = _FakeAdService()..privacyRequired = true;
        final controller = MonetizationController(service);
        expect(controller.privacyOptionsRequired, isTrue);
        expect(await controller.showPrivacyOptions(), isTrue);
        expect(service.privacyCalls, 1);
      },
    );

    test('daily runs are excluded from rewards and frequency counts', () async {
      final service = _FakeAdService();
      final controller = MonetizationController(service);
      for (var index = 1; index <= 6; index++) {
        controller.recordCompletedRun('daily-$index', isNormalMode: false);
      }
      expect(
        controller.canOfferRewarded(
          isNormalMode: false,
          runSaved: true,
          coinsCollected: 10,
          alreadyConsumed: false,
        ),
        isFalse,
      );
      expect(await controller.showInterstitialAtBreak(), isFalse);
      expect(service.interstitialCalls, 0);
    });

    test('consent denial and failed loads leave play unblocked', () async {
      final service = _FakeAdService()
        ..permitted = false
        ..rewardReady = false
        ..interstitialIsReady = false;
      final controller = MonetizationController(service);
      expect(
        controller.canOfferRewarded(
          isNormalMode: true,
          runSaved: true,
          coinsCollected: 10,
          alreadyConsumed: false,
        ),
        isFalse,
      );
      expect(await controller.showRewarded(), RewardedAdOutcome.unavailable);
      expect(service.rewardCalls, 0);
      for (var index = 1; index <= 3; index++) {
        controller.recordCompletedRun('run-$index', isNormalMode: true);
      }
      expect(await controller.showInterstitialAtBreak(), isFalse);
      expect(service.interstitialCalls, 0);
    });
  });

  group('rewarded claim contract', () {
    test('parses only non-sensitive server-confirmed fields', () {
      final claim = RewardedBonusClaim.fromJson({
        'run_id': '550e8400-e29b-41d4-a716-446655440000',
        'bonus_coins': 6,
        'new_total_coins': 120,
        'already_claimed': false,
        'profile_updated_at': '2026-09-28T10:00:00Z',
      });
      expect(claim.bonusCoins, 6);
      expect(claim.totalCoins, 120);
      expect(claim.profileUpdatedAt.isUtc, isTrue);
    });

    test('migration derives owner and amount and permits one claim', () {
      final sql = File(
        'supabase/migrations/20260928035631_phase13a_rewarded_bonus.sql',
      ).readAsStringSync();
      expect(sql, contains('v_user uuid := auth.uid()'));
      expect(sql, isNot(contains('p_user_id')));
      expect(sql, isNot(contains('p_bonus')));
      expect(sql, contains('primary key (user_id, run_id)'));
      expect(sql, contains('on conflict (user_id, run_id) do nothing'));
      expect(sql, contains('and not r.is_daily'));
      expect(sql, contains('least(25, greatest(1'));
      expect(
        sql,
        contains(
          'alter table public.rewarded_ad_claims enable row level security',
        ),
      );
      expect(sql, contains('revoke all on public.rewarded_ad_claims'));
      expect(sql, contains('to authenticated;'));
    });

    testWidgets('reward action does not replace restart or home', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverOverlay(
            score: 100,
            coins: 8,
            paused: false,
            savePhase: SavePhase.saved,
            rewardActionLabel: 'WATCH VIDEO · +4 COINS',
            onReward: () {},
            onContinue: () {},
            onHome: () {},
          ),
        ),
      );
      expect(find.text('WATCH VIDEO · +4 COINS'), findsOneWidget);
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('release preparation contract', () {
    test(
      'manifest and Gradle reject debug signing and sample release app IDs',
      () {
        final manifest = File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync();
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(manifest, contains(r'android:value="${adMobAppId}"'));
        expect(gradle, contains('compileSdk = 36'));
        expect(gradle, contains('targetSdk = 36'));
        expect(gradle, contains('googleSamplePublisherId in publisherIds'));
        expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      },
    );

    test('release keeps the Room database constructor used by WorkManager', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final proguard = File('android/app/proguard-rules.pro')
          .readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(gradle, contains('proguardFiles("proguard-rules.pro")'));
      expect(
        proguard,
        contains('-keep class * extends androidx.room.RoomDatabase'),
      );
      expect(proguard, contains('<init>();'));
      expect(pubspec, contains('version: 1.0.1+2'));
    });

    test('privacy page and unpublished app-ads template exist', () {
      final privacy = File('web/privacy/index.html').readAsStringSync();
      final template = File('docs/app-ads.txt.example').readAsStringSync();
      expect(privacy, contains('Sky Hopper Privacy Policy'));
      expect(privacy, contains('Google Mobile Ads'));
      expect(template, contains('<PUBLISHER_ID>'));
      expect(
        File('.gitignore').readAsStringSync(),
        contains('/web/app-ads.txt'),
      );
    });
  });
}
