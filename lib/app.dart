import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';

class TransitGoApp extends StatelessWidget {
  const TransitGoApp({super.key});

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
      home: const SplashScreen(),
    );
  }
}