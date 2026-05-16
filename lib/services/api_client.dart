// lib/services/api_client.dart

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ApiClient {
  static final String baseUrl = AppConfig.apiBaseUrl;
  late Dio _dio;
  late Box<String> _authBox;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );

    // Add logging interceptor for debugging (debug mode only)
    if (kDebugMode) {
      _dio.interceptors.add(LoggingInterceptor());
    }

    // Add authentication token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            _authBox = await Hive.openBox<String>('auth');
            final token = _authBox.get('access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              if (kDebugMode) print('[ApiClient] Authorization header added');
            }
          } catch (e) {
            if (kDebugMode) print('[ApiClient] ❌ Error getting token: $e');
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            print('[ApiClient] ❌ DIO ERROR: ${error.type}');
            print('[ApiClient] Message: ${error.message}');
            print('[ApiClient] Status: ${error.response?.statusCode}');
          }
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      print('[ApiClient] Initialized with base URL: $baseUrl');
    }
  }

  Future<Response> post(
    String path, {
    required Map<String, dynamic> data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
    );
  }

  Future<Response> put(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  void setAuthToken(String token) async {
    try {
      _authBox = await Hive.openBox<String>('auth');
      await _authBox.put('access_token', token);
      if (kDebugMode) print('[ApiClient] ✓ Token saved');
    } catch (e) {
      if (kDebugMode) print('[ApiClient] ❌ Error saving token: $e');
    }
  }

  Future<void> clearAuthToken() async {
    try {
      _authBox = await Hive.openBox<String>('auth');
      await _authBox.delete('access_token');
      if (kDebugMode) print('[ApiClient] ✓ Token cleared');
    } catch (e) {
      if (kDebugMode) print('[ApiClient] ❌ Error clearing token: $e');
    }
  }
}

// ============================================================================
// LOGGING INTERCEPTOR FOR DEBUGGING
// ============================================================================

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('\\n═══════════════════════════════════════════════════════════');
    print('📤 REQUEST');
    print('URI: ${options.uri}');
    print('Method: ${options.method}');
    print('Headers: ${options.headers}');
    if (options.data != null) {
      print('Body: ${options.data}');
    }
    print('═══════════════════════════════════════════════════════════\\n');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('\\n═══════════════════════════════════════════════════════════');
    print('📥 RESPONSE');
    print('URI: ${response.requestOptions.uri}');
    print('Status: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.data}');
    print('═══════════════════════════════════════════════════════════\\n');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('\\n═══════════════════════════════════════════════════════════');
    print('❌ ERROR');
    print('URI: ${err.requestOptions.uri}');
    print('Error Type: ${err.type}');
    print('Message: ${err.message}');
    print('Status: ${err.response?.statusCode}');
    print('Response: ${err.response?.data}');
    print('═══════════════════════════════════════════════════════════\\n');
    handler.next(err);
  }
}
