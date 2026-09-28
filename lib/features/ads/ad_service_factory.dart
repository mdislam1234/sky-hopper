import 'ad_service.dart';
import 'ad_service_factory_stub.dart'
    if (dart.library.io) 'ad_service_factory_io.dart';

AdService createAdService() => createPlatformAdService();
