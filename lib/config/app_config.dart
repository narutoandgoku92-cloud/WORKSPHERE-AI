// lib/config/app_config.dart

import 'package:flutter/foundation.dart';

class AppConfig {
  // App Configuration
  static const String appName = 'WorkSphere AI';
  static const String appVersion = '1.0.0';

  // Environment
  static const String environment = 'development'; // development, staging, production

  // API Configuration
  // IMPORTANT FOR PHYSICAL DEVICES:
  // Physical Android devices CANNOT use 10.0.2.2 (emulator proxy).
  // You MUST provide your PC's local network IP when running on real hardware:
  //
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000/api/v1
  //
  // Find your PC IP on Windows:   ipconfig | findstr IPv4
  // Find your PC IP on Mac/Linux: ifconfig | grep inet
  //
  // Ensure phone and PC are on same Wi-Fi. Emulator will use 10.0.2.2.
  static const String _environmentApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _androidEmulatorApiBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String _lanApiBaseUrl = 'http://<YOUR_LAN_IP>:8000/api/v1';

  static String get apiBaseUrl {
    // Priority 1: Explicit environment override (required for physical devices)
    if (_environmentApiBaseUrl.isNotEmpty) {
      if (kDebugMode) print('[AppConfig] ✓ Using API_BASE_URL: $_environmentApiBaseUrl');
      return _environmentApiBaseUrl;
    }

    // Priority 2: Web
    if (kIsWeb) {
      if (kDebugMode) print('[AppConfig] Using web API: $_lanApiBaseUrl');
      return _lanApiBaseUrl;
    }

    // Priority 3: Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (kDebugMode) {
        print('[AppConfig] ⚠️ ANDROID DETECTED: Using emulator URL');
        print('[AppConfig] ⚠️ If on PHYSICAL DEVICE, login will FAIL!');
        print('[AppConfig] ⚠️ Run: flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000/api/v1');
      }
      return _androidEmulatorApiBaseUrl;
    }

    // Default
    if (kDebugMode) print('[AppConfig] Using default API: $_lanApiBaseUrl');
    return _lanApiBaseUrl;
  }

  static const Duration apiTimeout = Duration(seconds: 30);

  // Firebase Configuration
  static const String sentryDsn = ''; // Add your Sentry DSN here

  // Feature Flags
  static const bool enableFaceRecognition = true;
  static const bool enableGpsVerification = true;
  static const bool enableNotifications = true;
  static const bool enableAnalytics = true;

  // Security
  static const int sessionTimeoutMinutes = 60;
  static const bool requireBiometricAuth = false;

  // UI Configuration
  static const double defaultBorderRadius = 8.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Attendance Configuration
  static const double gpsAccuracyThreshold = 100.0; // meters
  static const Duration faceRecognitionTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
}