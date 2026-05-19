// lib/config/app_config.dart

import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'WorkSphere AI';
  static const String appVersion = '1.0.0';

  static const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _defaultApiBaseUrl = String.fromEnvironment('API_DEFAULT_BASE_URL', defaultValue: '');

  static final Duration apiTimeout = Duration(seconds: int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 30));
  static const int maxRetryAttempts = 3;
  static const int maxRefreshRetries = 1;
  static const int retryBaseDelayMs = 500;

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _normalizeApiBaseUrl(_apiBaseUrl);
    }

    if (_defaultApiBaseUrl.isNotEmpty) {
      return _normalizeApiBaseUrl(_defaultApiBaseUrl);
    }

    if (environment == 'production' || environment == 'staging') {
      throw StateError('API_BASE_URL must be provided with --dart-define=API_BASE_URL for staging and production builds.');
    }

    if (kIsWeb) {
      throw StateError('Web builds must provide API_BASE_URL via --dart-define=API_BASE_URL');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _normalizeApiBaseUrl('http://10.0.2.2:8000/api/v1');
    }

    return _normalizeApiBaseUrl('http://127.0.0.1:8000/api/v1');
  }

  static String _normalizeApiBaseUrl(String url) {
    final sanitized = url.trim();
    final normalized = sanitized.endsWith('/') ? sanitized.substring(0, sanitized.length - 1) : sanitized;

    final uri = Uri.parse(normalized);
    if (isProduction && uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use https://');
    }

    final base = normalized.replaceAll(RegExp(r'(/api/v1)+$'), '');
    return '$base/api/v1';
  }

  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
  static bool get requireSecureTransport => isProduction || isStaging;

  static const bool enableFaceRecognition = true;
  static const bool enableGpsVerification = true;
  static const bool enableNotifications = true;
  static const bool enableAnalytics = true;

  static const int sessionTimeoutMinutes = 60;
  static const bool requireBiometricAuth = false;

  static const double defaultBorderRadius = 8.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  static const double gpsAccuracyThreshold = 100.0;
  static const Duration faceRecognitionTimeout = Duration(seconds: 30);
}
