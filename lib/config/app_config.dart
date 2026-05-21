import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'WorkSphere AI';
  static const String appVersion = '1.0.0';

  static const String environment =
      String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'development',
      );

  static const String _apiBaseUrl =
      String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '',
      );

  static const Duration apiTimeout =
      Duration(
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

  static String get apiBaseUrl {
    final base = _apiBaseUrl.isNotEmpty
        ? _apiBaseUrl
        : _getDefaultBaseUrl();

    return _normalizeApiBaseUrl(base);
  }

  static String _getDefaultBaseUrl() {
    // Production always uses Render
    if (isProduction) {
      return "https://worksphere-ai.onrender.com";
    }

    // Flutter web
    if (kIsWeb) {
      return "https://worksphere-ai.onrender.com";
    }

    // Android emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    }

    // iOS simulator / desktop
    return "http://127.0.0.1:8000";
  }

  static String _normalizeApiBaseUrl(String url) {
    final sanitized = url.trim();

    final uri = Uri.tryParse(sanitized);

    if (uri == null || uri.scheme.isEmpty) {
      throw StateError(
        'Invalid API_BASE_URL: $sanitized',
      );
    }

    if (isProduction && uri.scheme != 'https') {
      throw StateError(
        'Production API_BASE_URL must use https://',
      );
    }

    final base = sanitized.replaceAll(
      RegExp(r'(/api/v1)+$'),
      '',
    );

    return '$base/api/v1';
  }

  static bool get isProduction =>
      environment == 'production';
}