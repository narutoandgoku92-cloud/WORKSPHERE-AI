// lib/services/api_client.dart

import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../config/app_config.dart';

class ApiClient {
  static final String baseUrl = AppConfig.apiBaseUrl;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _refreshing = false;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: AppConfig.apiTimeout,
            receiveTimeout: AppConfig.apiTimeout,
            sendTimeout: AppConfig.apiTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!await _hasNetworkConnection()) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'No network connection',
                type: DioExceptionType.connectionError,
              ),
            );
          }

          final accessToken = await _readToken(_accessTokenKey);
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          final requestOptions = error.requestOptions;
          final statusCode = error.response?.statusCode;

          if (_isUnauthorized(statusCode) && !requestOptions.extra.containsKey('refresh_attempted')) {
            try {
              await _refreshTokens();
              requestOptions.extra['refresh_attempted'] = true;
              final response = await _retryRequest(requestOptions);
              return handler.resolve(response);
            } catch (e) {
              await clearAuthTokens();
            }
          }

          if (_shouldRetry(error) && _retryCount(requestOptions) < AppConfig.maxRetryAttempts) {
            final retryResponse = await _retryRequest(requestOptions);
            return handler.resolve(retryResponse);
          }

          return handler.next(error);
        },
      ),
    );
  }

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<bool> _hasNetworkConnection() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.isEmpty || connectivityResults.contains(ConnectivityResult.none)) {
      return false;
    }
    return await InternetConnectionChecker().hasConnection;
  }

  bool _isUnauthorized(int? statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  int _retryCount(RequestOptions options) {
    return (options.extra['retry_count'] as int?) ?? 0;
  }

  Future<String?> _readToken(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      log('Secure storage read failed: $e', name: 'ApiClient');
      return null;
    }
  }

  Future<void> _writeToken(String key, String? value) async {
    if (value == null) return;
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      log('Secure storage write failed: $e', name: 'ApiClient');
    }
  }

  Future<void> setAuthTokens({required String accessToken, required String refreshToken}) async {
    await _writeToken(_accessTokenKey, accessToken);
    await _writeToken(_refreshTokenKey, refreshToken);
  }

  Future<void> clearAuthTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      log('Secure storage delete failed: $e', name: 'ApiClient');
    }
  }

  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final attempt = _retryCount(requestOptions) + 1;
    final latestAccessToken = await _readToken(_accessTokenKey);
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (latestAccessToken != null && latestAccessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $latestAccessToken';
    }

    final options = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      extra: {
        ...requestOptions.extra,
        'retry_count': attempt,
      },
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
    );

    await Future<void>.delayed(Duration(milliseconds: AppConfig.retryBaseDelayMs * attempt));
    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<void> _refreshTokens() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final refreshToken = await _readToken(_refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        throw StateError('No refresh token available');
      }

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final accessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;
      if (accessToken == null || newRefreshToken == null) {
        throw StateError('Refresh response did not contain tokens');
      }

      await setAuthTokens(accessToken: accessToken, refreshToken: newRefreshToken);
    } finally {
      _refreshing = false;
    }
  }

  Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    Map<String, dynamic>? data,
    Options? options,
  }) async {
    return _dio.put(path, data: data, options: options);
  }

  Future<Response> delete(
    String path, {
    Options? options,
  }) async {
    return _dio.delete(path, options: options);
  }
}
