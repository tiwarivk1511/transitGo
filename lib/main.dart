import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/cache/offline_cache.dart';
import 'data/sources/station_source.dart';
import 'services/wake_me_up_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parallel init — fast startup
  await Future.wait([
    StationSource.load(),        // Offline station data (instant)
    OfflineCache.instance,       // SQLite cache
    WakeMeUpService.init(),      // Alarm service
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const TransitGoApp());
}