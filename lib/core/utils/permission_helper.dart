import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request location and notification permissions across supported mobile platforms.
  /// On Web and Desktop (Windows/Linux/macOS), permissions are managed by the browser/OS natively.
  static Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid || Platform.isIOS) {
      final statuses = await [
        Permission.location,
        Permission.notification,
      ].request();

      final locationGranted = statuses[Permission.location]?.isGranted ?? false;
      final notificationGranted = statuses[Permission.notification]?.isGranted ?? false;

      return locationGranted || notificationGranted;
    }

    return true;
  }

  static Future<bool> requestLocation() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> requestNotification() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
