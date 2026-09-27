import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';
import 'core/cache/offline_cache.dart';
import 'data/sources/station_source.dart';
import 'services/wake_me_up_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows, Linux, and macOS
  if (!kIsWeb) {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (_) {}
  }

  // Parallel init with safety check for Web
  try {
    await Future.wait([
      StationSource.load(),
      kIsWeb ? Future.value() : OfflineCache.instance,
      WakeMeUpService.init(),
    ]);
  } catch (e) {
    debugPrint('Initialization warning: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const TransitGoApp());
}
