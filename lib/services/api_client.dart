import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  late final FlutterSecureStorage _secureStorage;
  Box<String>? _hiveBox;
  bool _isWebPlatform = false;

  String? _accessToken;
  String? _refreshTokenValue;
  bool _refreshing = false;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  ApiClient() {
    _isWebPlatform = kIsWeb;
    _secureStorage = const FlutterSecureStorage();
    
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        sendTimeout: AppConfig.apiTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    log('🔧 ApiClient initialized for ${_isWebPlatform ? 'WEB' : 'MOBILE'} platform');
    log('📍 Base URL: ${AppConfig.apiBaseUrl}');

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          log('📤 REQUEST: ${options.method} ${options.path}');

          if (!await _hasNetworkConnection()) {
            log('❌ NO NETWORK CONNECTION');
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'No internet connection',
                type: DioExceptionType.connectionError,
              ),
            );
          }

          final token = _accessToken ?? await _read(_accessTokenKey);

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            log('✓ Authorization header added (token length: ${token.length})');
          } else {
            log('⚠️ No access token available');
          }

          handler.next(options);
        },

        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final req = error.requestOptions;

          log('❌ ERROR: ${req.method} ${req.path}');
          log('   Status: $status');
          log('   Error: ${error.error}');
          log('   Response: ${error.response?.data}');

          final isUnauthorized = status == 401 || status == 403;

          if (isUnauthorized && !_refreshing) {
            log('🔄 Attempting token refresh...');
            try {
              await _refreshAuthToken();
              final retry = await _retry(req);
              log('✓ Request retry successful');
              return handler.resolve(retry);
            } catch (e) {
              log('❌ Token refresh failed: $e');
              await clearAuthTokens();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  // =========================
  // NETWORK CHECK
  // =========================
  Future<bool> _hasNetworkConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return false;

    return InternetConnectionChecker().hasConnection;
  }

  // =========================
  // TOKEN STORAGE - Platform aware
  // =========================
  Future<String?> _read(String key) async {
    try {
      if (_isWebPlatform) {
        // Web: use Hive only
        _hiveBox ??= await Hive.openBox<String>('auth_web');
        return _hiveBox?.get(key);
      } else {
        // Mobile: use FlutterSecureStorage
        return await _secureStorage.read(key: key);
      }
    } catch (e) {
      log("❌ Storage read error for $key: $e");
      // Fallback to Hive
      try {
        _hiveBox ??= await Hive.openBox<String>('auth_mobile');
        return _hiveBox?.get(key);
      } catch (e2) {
        log("❌ Hive fallback also failed: $e2");
        return null;
      }
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      if (_isWebPlatform) {
        // Web: use Hive only
        _hiveBox ??= await Hive.openBox<String>('auth_web');
        await _hiveBox?.put(key, value);
      } else {
        // Mobile: use FlutterSecureStorage
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e) {
      log("❌ Storage write error for $key: $e");
      // Fallback to Hive
      try {
        _hiveBox ??= await Hive.openBox<String>('auth_mobile');
        await _hiveBox?.put(key, value);
      } catch (e2) {
        log("❌ Hive fallback also failed: $e2");
      }
    }
  }

  Future<void> setAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshTokenValue = refreshToken;

    await _write(_accessTokenKey, accessToken);
    await _write(_refreshTokenKey, refreshToken);
  }

  Future<void> clearAuthTokens() async {
  _accessToken = null;
  _refreshTokenValue = null;

  try {
    if (_isWebPlatform) {
      _hiveBox ??= await Hive.openBox<String>('auth_web');
      await _hiveBox?.delete(_accessTokenKey);
      await _hiveBox?.delete(_refreshTokenKey);
    } else {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    }
  } catch (e) {
    log('❌ Failed to clear tokens: $e');
  }
}

  Future<void> initialize() async {
    _accessToken = await _read(_accessTokenKey);
    _refreshTokenValue = await _read(_refreshTokenKey);
  }

  Future<bool> hasAccessToken() async {
    return (_accessToken ?? await _read(_accessTokenKey))?.isNotEmpty ?? false;
  }

  // =========================
  // AUTH REFRESH
  // =========================
  Future<void> _refreshAuthToken() async {
    if (_refreshing) return;
    _refreshing = true;

    try {
      final refresh = await _read(_refreshTokenKey);

      if (refresh == null) {
        throw Exception("No refresh token");
      }

      final res = await _dio.post(
        '/auth/refresh',  // ✓ FIXED: baseUrl already includes /api/v1
        data: {'refresh_token': refresh},
      );

      final newAccess = res.data['access_token'];
      final newRefresh = res.data['refresh_token'];

      if (newAccess == null || newRefresh == null) {
        throw Exception("Invalid refresh response");
      }

      await setAuthTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
    } finally {
      _refreshing = false;
    }
  }

  // =========================
  // RETRY REQUEST
  // =========================
  Future<Response> _retry(RequestOptions request) async {
    final token = await _read(_accessTokenKey);

    final headers = Map<String, dynamic>.from(request.headers);

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return _dio.request(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      options: Options(
        method: request.method,
        headers: headers,
      ),
    );
  }

  // =========================
  // HTTP METHODS
  // =========================
  Future<Response> post(String path, {dynamic data , Options? options}) {
    return _dio.post(path, data: data, options: options);
  }

  Future<Response> get(String path, {Options? options}) {
    return _dio.get(path, options: options);
  }

  Future<Response> put(String path, {dynamic data, Options? options}) {
    return _dio.put(path, data: data, options: options);
  }

  Future<Response> delete(String path,{Options? options}) {
    return _dio.delete(path, options: options);
  }

  // =========================
  // HEALTH CHECK
  // =========================
  Future<bool> healthCheck() async {
  try {
    final baseUrl = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');

    final response = await Dio().get(
      '$baseUrl/health',
    );

    return response.statusCode == 200;
  } catch (e) {
    log('❌ Health check failed: $e');
    return false;
  }
}
}