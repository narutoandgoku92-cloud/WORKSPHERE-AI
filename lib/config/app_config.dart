import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'WorkSphere AI';
  static const String appVersion = '1.0.0';

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const Duration apiTimeout = Duration(
    seconds: int.fromEnvironment(
      'API_TIMEOUT_SECONDS',
      defaultValue: 30,
    ),
  );

  static const int maxRetryAttempts = 3;
  static const int maxRefreshRetries = 1;
  static const int retryBaseDelayMs = 500;

  // =========================
  // FEATURE FLAGS
  // =========================
  static const bool enableFaceRecognition = true;
  static const bool enableGpsVerification = true;
  static const bool enableNotifications = true;
  static const bool requireBiometricAuth = false;

  // =========================
  // API BASE URL (FIXED)
  // =========================
  static String get apiBaseUrl {
    // If manually provided (CI / env override)
    if (_apiBaseUrl.isNotEmpty) {
      return '$_apiBaseUrl/api/v1';
    }

    // ALWAYS use Render for everything (web + mobile + release)
    return 'https://worksphere-ai.onrender.com/api/v1';
  }

  static bool get isProduction => environment == 'production';
}