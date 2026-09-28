import 'dart:io';

import 'ad_service.dart';
import 'google_mobile_ads_service.dart';

AdService createPlatformAdService() =>
    Platform.isAndroid ? GoogleMobileAdsService() : NoopAdService();
