import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sky_hopper/features/ads/ad_configuration.dart';

void main() {
  group('production AdMob identifiers', () {
    test('accepts production-shaped unit IDs with one publisher', () {
      const rewarded = 'ca-app-pub-1234567890123456/1234567890';
      const interstitial = 'ca-app-pub-1234567890123456/0987654321';
      expect(AdConfiguration.isProductionAdUnitId(rewarded), isTrue);
      expect(AdConfiguration.isProductionAdUnitId(interstitial), isTrue);
      expect(
        AdConfiguration.publisherIdFor(rewarded),
        AdConfiguration.publisherIdFor(interstitial),
      );
    });

    test('rejects Google sample and malformed unit IDs', () {
      expect(
        AdConfiguration.isProductionAdUnitId(
          AdConfiguration.androidTestRewardedId,
        ),
        isFalse,
      );
      for (final value in [
        '',
        'ca-app-pub-123/456',
        'pub-1234567890123456',
        'ca-app-pub-1234567890123456~1234567890',
      ]) {
        expect(AdConfiguration.isProductionAdUnitId(value), isFalse);
      }
    });
  });

  group('release configuration contract', () {
    late String gradle;
    late String ignore;
    late String template;
    late String mobileAdsService;

    setUpAll(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
      ignore = File('.gitignore').readAsStringSync();
      template = File('android/admob_config.local.json.example')
          .readAsStringSync();
      mobileAdsService = File('lib/features/ads/google_mobile_ads_service.dart')
          .readAsStringSync();
    });

    test('one ignored Dart-define file carries all Android IDs', () {
      for (final key in [
        'ADMOB_ANDROID_APP_ID',
        'ADMOB_REWARDED_AD_UNIT_ID',
        'ADMOB_INTERSTITIAL_AD_UNIT_ID',
      ]) {
        expect(template, contains(key));
        expect(gradle, contains(key));
      }
      expect(ignore, contains('/android/admob_config.local.json'));
      expect(
        File('android/admob_config.local.json.example').existsSync(),
        isTrue,
      );
    });

    test(
      'release validation covers missing malformed sample and mixed IDs',
      () {
        expect(gradle, contains('missingAdMobNames.isNotEmpty()'));
        expect(gradle, contains('appIdPattern.matchEntire'));
        expect(gradle, contains('adUnitIdPattern.matchEntire'));
        expect(gradle, contains('googleSamplePublisherId in publisherIds'));
        expect(gradle, contains('publisherIds.size != 1'));
        expect(gradle, contains('if (!releaseSigningConfigured)'));
        expect(gradle, isNot(contains(r'${releaseAdMobAppId}')));
        expect(gradle, isNot(contains(r'${releaseRewardedAdUnitId}')));
        expect(gradle, isNot(contains(r'${releaseInterstitialAdUnitId}')));
      },
    );

    test('debug manifest requires the ignored real app ID', () {
      expect(gradle, contains('JsonSlurper().parse(localAdMobConfigFile)'));
      expect(gradle, contains('developmentAndroidBuildRequested'));
      expect(gradle, contains('debugAppMatch == null'));
      expect(
        gradle,
        contains('debugAppMatch.groupValues[1] == googleSamplePublisherId'),
      );
      expect(
        gradle,
        contains('manifestPlaceholders["adMobAppId"] = debugAdMobAppId'),
      );
      expect(gradle, isNot(contains('3347511713')));
    });

    test('UMP test device and geography override are debug-only', () {
      expect(mobileAdsService, contains('if (!kDebugMode)'));
      expect(mobileAdsService, contains('CB2CF1764252D069F3F371B3CA255E59'));
      expect(mobileAdsService, contains('UMP_DEBUG_FORCE_EEA'));
      expect(mobileAdsService, contains('DebugGeography.debugGeographyEea'));
      expect(
        mobileAdsService,
        contains('DebugGeography.debugGeographyDisabled'),
      );
    });

    test('UMP errors log sanitized code and message only in debug', () {
      expect(mobileAdsService, contains('errorCode=\${error.errorCode}'));
      expect(mobileAdsService, contains('message="\$message"'));
      expect(mobileAdsService, contains('[redacted-ad-id]'));
      expect(mobileAdsService, contains('[redacted-url]'));
      expect(mobileAdsService, contains('[redacted-token]'));
    });

    test('publisher file is separate ignored public-hosting input', () {
      expect(ignore, contains('/web/app-ads.txt'));
      expect(
        File('docs/app-ads.txt.example').readAsStringSync(),
        contains('pub-<PUBLISHER_ID>'),
      );
      expect(template, isNot(contains('PUBLISHER_ID":')));
    });

    test('Web factory remains a no-op without mobile SDK import', () {
      final factory = File('lib/features/ads/ad_service_factory.dart')
          .readAsStringSync();
      final stub = File('lib/features/ads/ad_service_factory_stub.dart')
          .readAsStringSync();
      expect(factory, contains("if (dart.library.io)"));
      expect(stub, contains('NoopAdService'));
      expect(stub, isNot(contains('google_mobile_ads')));
    });
  });
}
