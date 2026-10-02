import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/startup_error_screen.dart';

class TransitGoApp extends StatelessWidget {
  /// Populated by `main()` when Firebase / Remote Config failed during
  /// startup. When non-null the app skips the normal flow and shows a
  /// blocking diagnostic screen instead of silently 401-ing on every
  /// API call.
  final String? startupError;

  const TransitGoApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TransitGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F2FE),
          secondary: Color(0xFF00F2FE),
          surface: Color(0xFF1C2541),
        ),
        fontFamily: 'Inter',
      ),
      home: startupError == null
          ? const SplashScreen()
          : StartupErrorScreen(message: startupError!),
    );
  }
}