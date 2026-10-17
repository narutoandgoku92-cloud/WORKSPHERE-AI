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

    log(
      'ApiClient initialized for '
      '${_isWebPlatform ? 'WEB' : 'MOBILE'} platform',
    );
    log('Base URL: ${AppConfig.apiBaseUrl}');

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          log('REQUEST: ${options.method} ${options.uri}');

          try {
            final hasNetwork = await _hasNetworkConnection();

            if (!hasNetwork) {
              log('No network connection');

              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'No network connection',
                  type: DioExceptionType.connectionError,
                ),
              );
            }

            final token =
                _accessToken ?? await _read(_accessTokenKey);

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
              log('Authorization header added');
            } else {
              log('No access token available');
            }

            handler.next(options);
          } catch (e, stackTrace) {
            log('Request interceptor failed: $e');
            log('$stackTrace');

            handler.reject(
              DioException(
                requestOptions: options,
                error: e,
                type: DioExceptionType.unknown,
              ),
            );
          }
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final request = error.requestOptions;

          log('ERROR: ${request.method} ${request.uri}');
          log('Status: $status');
          log('Error: ${error.error}');
          log('Response: ${error.response?.data}');

          final isUnauthorized = status == 401 || status == 403;

          // Do not attempt token refresh on the refresh endpoint itself.
          final isRefreshRequest =
              request.path.endsWith('/auth/refresh');

          if (isUnauthorized &&
              !_refreshing &&
              !isRefreshRequest) {
            log('Attempting token refresh...');

            try {
              await _refreshAuthToken();

              final retryResponse = await _retry(request);

              log('Request retry successful');
              return handler.resolve(retryResponse);
            } catch (e, stackTrace) {
              log('Token refresh failed: $e');
              log('$stackTrace');

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
    // Browsers do not support the InternetAddress operation
    // used by internet_connection_checker in this environment.
    //
    // Allow Dio to make the actual HTTP request on Web.
    // Dio will report connection failures if the server is
    // unreachable. The login screen separately checks /health.
    if (_isWebPlatform) {
      return true;
    }

    try {
      final result = await Connectivity().checkConnectivity();

      if (result.contains(ConnectivityResult.none)) {
        return false;
      }

      return await InternetConnectionChecker().hasConnection;
    } catch (e, stackTrace) {
      log('Network check failed: $e');
      log('$stackTrace');
      return false;
    }
  }

  // =========================
  // TOKEN STORAGE
  // =========================

  Future<String?> _read(String key) async {
    try {
      if (_isWebPlatform) {
        _hiveBox ??= await Hive.openBox<String>('auth_web');
        return _hiveBox?.get(key);
      }

      return await _secureStorage.read(key: key);
    } catch (e, stackTrace) {
      log('Storage read error for $key: $e');
      log('$stackTrace');

      // Fallback to Hive if the primary storage fails.
      try {
        _hiveBox ??= await Hive.openBox<String>('auth_mobile');
        return _hiveBox?.get(key);
      } catch (fallbackError, fallbackStackTrace) {
        log('Hive fallback read failed: $fallbackError');
        log('$fallbackStackTrace');
        return null;
      }
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      if (_isWebPlatform) {
        _hiveBox ??= await Hive.openBox<String>('auth_web');
        await _hiveBox?.put(key, value);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e, stackTrace) {
      log('Storage write error for $key: $e');
      log('$stackTrace');

      try {
        _hiveBox ??= await Hive.openBox<String>('auth_mobile');
        await _hiveBox?.put(key, value);
      } catch (fallbackError, fallbackStackTrace) {
        log('Hive fallback write failed: $fallbackError');
        log('$fallbackStackTrace');
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
    } catch (e, stackTrace) {
      log('Failed to clear tokens: $e');
      log('$stackTrace');
    }
  }

  Future<void> initialize() async {
    _accessToken = await _read(_accessTokenKey);
    _refreshTokenValue = await _read(_refreshTokenKey);
  }

  Future<bool> hasAccessToken() async {
    final token = _accessToken ?? await _read(_accessTokenKey);
    return token?.isNotEmpty ?? false;
  }

  // =========================
  // AUTH REFRESH
  // =========================

  Future<void> _refreshAuthToken() async {
    if (_refreshing) {
      throw StateError('Token refresh is already in progress');
    }

    _refreshing = true;

    try {
      final refresh =
          _refreshTokenValue ?? await _read(_refreshTokenKey);

      if (refresh == null || refresh.isEmpty) {
        throw Exception('No refresh token available');
      }

      // Use a separate Dio instance so the refresh request
      // does not recursively enter this client's interceptors.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.apiTimeout,
          receiveTimeout: AppConfig.apiTimeout,
          sendTimeout: AppConfig.apiTimeout,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid refresh response format');
      }

      final newAccess = data['access_token'];
      final newRefresh = data['refresh_token'];

      if (newAccess is! String ||
          newAccess.isEmpty ||
          newRefresh is! String ||
          newRefresh.isEmpty) {
        throw Exception('Refresh response did not contain valid tokens');
      }

      await setAuthTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      log('Authentication tokens refreshed successfully');
    } finally {
      _refreshing = false;
    }
  }

  // =========================
  // RETRY REQUEST
  // =========================

  Future<Response<dynamic>> _retry(
    RequestOptions request,
  ) async {
    final token = _accessToken ?? await _read(_accessTokenKey);

    final headers = Map<String, dynamic>.from(request.headers);

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return _dio.request<dynamic>(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      options: Options(
        method: request.method,
        headers: headers,
        contentType: request.contentType,
        responseType: request.responseType,
        followRedirects: request.followRedirects,
        receiveDataWhenStatusError: request.receiveDataWhenStatusError,
        validateStatus: request.validateStatus,
      ),
      cancelToken: request.cancelToken,
      onSendProgress: request.onSendProgress,
      onReceiveProgress: request.onReceiveProgress,
    );
  }

  // =========================
  // HTTP METHODS
  // =========================

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.post<dynamic>(
      path,
      data: data,
      options: options,
    );
  }

  Future<Response<dynamic>> get(
    String path, {
    Options? options,
  }) {
    return _dio.get<dynamic>(
      path,
      options: options,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.put<dynamic>(
      path,
      data: data,
      options: options,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Options? options,
  }) {
    return _dio.delete<dynamic>(
      path,
      options: options,
    );
  }

  // =========================
  // HEALTH CHECK
  // =========================

  Future<bool> healthCheck() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');

      // Use a separate Dio request so health checking does not
      // depend on authentication or the network interceptor.
      final healthDio = Dio(
        BaseOptions(
          connectTimeout: AppConfig.apiTimeout,
          receiveTimeout: AppConfig.apiTimeout,
        ),
      );

      final response = await healthDio.get<dynamic>(
        '$baseUrl/health',
      );

      final healthy = response.statusCode == 200;

      log('Backend health check: $healthy');
      return healthy;
    } on DioException catch (e, stackTrace) {
      log('Backend health check failed: ${e.message}');
      log('$stackTrace');
      return false;
    } catch (e, stackTrace) {
      log('Unexpected health check error: $e');
      log('$stackTrace');
      return false;
    }
  }
}
