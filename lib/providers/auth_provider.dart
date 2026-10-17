
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class AuthState {
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final DateTime? tokenExpiresAt;
  final bool isTokenExpired;

  AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.tokenExpiresAt,
    this.isTokenExpired = false,
  });

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    DateTime? tokenExpiresAt,
    bool? isTokenExpired,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      isTokenExpired: isTokenExpired ?? this.isTokenExpired,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;

  Timer? _tokenRefreshTimer;
  Timer? _expirationCheckTimer;
  Box<String>? _authBox;

  bool _initializing = false;

  static const int _tokenRefreshMinutesBefore = 5;
  static const int _expirationCheckIntervalSeconds = 60;

  AuthNotifier(this.apiClient) : super(AuthState()) {
    _initializeAuth();
  }

  // --------------------------------------------------
  // INITIALIZE AUTHENTICATION
  // --------------------------------------------------

  Future<void> _initializeAuth() async {
    if (_initializing) return;
    _initializing = true;

    try {
      await apiClient.initialize();

      _authBox = await Hive.openBox<String>('auth');

      final userString = _authBox?.get('user');
      final accessToken = _authBox?.get('access_token');
      final refreshToken = _authBox?.get('refresh_token');
      final expiresAtString = _authBox?.get('token_expires_at');

      User? user;

      if (userString != null && userString.isNotEmpty) {
        final decodedUser = jsonDecode(userString);

        if (decodedUser is Map<String, dynamic>) {
          user = User.fromJson(decodedUser);
        } else {
          throw const FormatException(
            'Saved user data is not a JSON object.',
          );
        }
      }

      DateTime? expiresAt;

      if (expiresAtString != null) {
        expiresAt = DateTime.tryParse(expiresAtString);
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        // Do not restore an authenticated state without a user.
        if (user == null) {
          log('Saved access token exists, but saved user is missing.');
          await logout();
          return;
        }

        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          log('Saved access token has expired.');

          if (refreshToken == null || refreshToken.isEmpty) {
            await logout();
            return;
          }
        }

        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenExpiresAt: expiresAt,
          isTokenExpired:
              expiresAt != null && DateTime.now().isAfter(expiresAt),
        );

        _setupExpirationCheckTimer();

        if (expiresAt != null) {
          _setupTokenRefreshTimer();
        }

        log('Authentication state restored.');
      } else {
        log('No saved access token found.');
      }
    } catch (e, stackTrace) {
      log('Authentication initialization failed: $e');
      log('$stackTrace');
    } finally {
      _initializing = false;
    }
  }

  // --------------------------------------------------
  // TOKEN REFRESH TIMER
  // --------------------------------------------------

  void _setupTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();

    final expiresAt = state.tokenExpiresAt;

    if (expiresAt == null || state.refreshToken == null) {
      return;
    }

    final refreshAt = expiresAt.subtract(
      const Duration(minutes: _tokenRefreshMinutesBefore),
    );

    final duration = refreshAt.difference(DateTime.now());

    if (duration.isNegative) {
      log('Token is expiring soon; refreshing now.');
      unawaited(_refreshAccessToken());
      return;
    }

    log('Token refresh scheduled in ${duration.inMinutes} minutes.');

    _tokenRefreshTimer = Timer(duration, () {
      unawaited(_refreshAccessToken());
    });
  }

  void _setupExpirationCheckTimer() {
    _expirationCheckTimer?.cancel();

    _expirationCheckTimer = Timer.periodic(
      const Duration(seconds: _expirationCheckIntervalSeconds),
      (_) {
        final expiresAt = state.tokenExpiresAt;

        if (expiresAt == null) return;

        if (DateTime.now().isAfter(expiresAt)) {
          if (!state.isTokenExpired) {
            log('Access token expired.');
            state = state.copyWith(isTokenExpired: true);
          }

          if (state.refreshToken != null &&
              state.refreshToken!.isNotEmpty) {
            unawaited(_refreshAccessToken());
          } else {
            unawaited(logout());
          }
        } else {
          final remaining = expiresAt.difference(DateTime.now());

          if (remaining.inMinutes <= _tokenRefreshMinutesBefore) {
            _setupTokenRefreshTimer();
          }
        }
      },
    );
  }

  // --------------------------------------------------
  // REFRESH ACCESS TOKEN
  // --------------------------------------------------

  Future<void> _refreshAccessToken() async {
    final refreshToken = state.refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      log('Cannot refresh token: no refresh token available.');
      await logout();
      return;
    }

    try {
      log('Refreshing access token.');

      final response = await apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'Refresh response must be a JSON object.',
        );
      }

      final newAccessToken = data['access_token'];
      final newRefreshToken = data['refresh_token'];
      final expiresInValue = data['expires_in'];

      if (newAccessToken is! String || newAccessToken.isEmpty) {
        throw const FormatException(
          'Refresh response has no valid access token.',
        );
      }

      final effectiveRefreshToken =
          newRefreshToken is String && newRefreshToken.isNotEmpty
              ? newRefreshToken
              : refreshToken;

      final expiresIn = expiresInValue is num
          ? expiresInValue.toInt()
          : 900;

      final newExpiresAt = DateTime.now().add(
        Duration(seconds: expiresIn),
      );

      await apiClient.setAuthTokens(
        accessToken: newAccessToken,
        refreshToken: effectiveRefreshToken,
      );

      _authBox ??= await Hive.openBox<String>('auth');

      await _authBox!.put('access_token', newAccessToken);
      await _authBox!.put('refresh_token', effectiveRefreshToken);
      await _authBox!.put(
        'token_expires_at',
        newExpiresAt.toIso8601String(),
      );

      state = state.copyWith(
        accessToken: newAccessToken,
        refreshToken: effectiveRefreshToken,
        tokenExpiresAt: newExpiresAt,
        isTokenExpired: false,
        error: null,
      );

      log('Access token refreshed successfully.');

      _setupTokenRefreshTimer();
    } catch (e, stackTrace) {
      log('Access token refresh failed: $e');
      log('$stackTrace');

      await logout();
    }
  }

  // --------------------------------------------------
  // LOGIN
  // --------------------------------------------------

  Future<bool> login(
    String email,
    String password, {
    int maxRetries = 3,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Enter your email and password.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    final attempts = maxRetries < 1 ? 1 : maxRetries;

    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        log('Login attempt $attempt/$attempts for ${email.trim()}');

        final response = await apiClient.post(
          '/auth/login',
          data: {
            'email': email.trim(),
            'password': password,
          },
        );

        final data = response.data;

        // Diagnostic information; never log actual token values.
        log('LOGIN HTTP STATUS: ${response.statusCode}');
        log('LOGIN RESPONSE TYPE: ${data.runtimeType}');

        if (data is! Map<String, dynamic>) {
          throw const FormatException(
            'Login response must be a JSON object.',
          );
        }

        log('LOGIN RESPONSE KEYS: ${data.keys.toList()}');

        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userData = data['user'];

        final expiresInValue = data['expires_in'];
        final expiresIn = expiresInValue is num
            ? expiresInValue.toInt()
            : 900;

        log(
          'ACCESS TOKEN PRESENT: '
          '${accessToken is String && accessToken.isNotEmpty}',
        );
        log(
          'REFRESH TOKEN PRESENT: '
          '${refreshToken is String && refreshToken.isNotEmpty}',
        );
        log('USER DATA TYPE: ${userData.runtimeType}');
        log('TOKEN EXPIRY SECONDS: $expiresIn');

        if (accessToken is! String || accessToken.isEmpty) {
          throw const FormatException(
            'Login response does not contain a valid access token.',
          );
        }

        if (refreshToken is! String || refreshToken.isEmpty) {
          throw const FormatException(
            'Login response does not contain a valid refresh token.',
          );
        }

        if (userData is! Map<String, dynamic>) {
          throw const FormatException(
            'Login response does not contain valid user data.',
          );
        }

        // Parse the user before changing authentication state.
        final user = User.fromJson(userData);

        final expiresAt = DateTime.now().add(
          Duration(seconds: expiresIn),
        );

        // Persist tokens and user data.
        _authBox ??= await Hive.openBox<String>('auth');

        await apiClient.setAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        await _authBox!.put('user', jsonEncode(userData));
        await _authBox!.put('access_token', accessToken);
        await _authBox!.put('refresh_token', refreshToken);
        await _authBox!.put(
          'token_expires_at',
          expiresAt.toIso8601String(),
        );

        // Update state only after parsing and persistence succeed.
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenExpiresAt: expiresAt,
          isTokenExpired: false,
          error: null,
        );

        log('Login completed successfully.');

        _setupTokenRefreshTimer();
        _setupExpirationCheckTimer();

        return true;
      } on DioException catch (e, stackTrace) {
        final responseData = e.response?.data;

        String message = 'Login failed. Please try again.';

        if (responseData is Map<String, dynamic>) {
          final detail = responseData['detail'];

          if (detail is String && detail.isNotEmpty) {
            message = detail;
          } else if (detail != null) {
            message = detail.toString();
          }
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          message = 'The request timed out. Please try again.';
        } else if (e.type == DioExceptionType.connectionError) {
          message = 'Unable to connect to the backend.';
        }

        log('Login request failed: $message');
        log('HTTP status: ${e.response?.statusCode}');
        log('$stackTrace');

        final status = e.response?.statusCode;

        // Do not retry invalid credentials or other client errors.
        final shouldRetry = status == null ||
            status == 408 ||
            status == 429 ||
            status >= 500;

        if (attempt < attempts && shouldRetry) {
          await Future.delayed(
            Duration(milliseconds: 500 * attempt),
          );
          continue;
        }

        state = state.copyWith(
          isLoading: false,
          error: message,
        );

        return false;
      } catch (e, stackTrace) {
        // Parsing or storage errors are not retried: the server may
        // already have authenticated the user successfully.
        log('Login processing failed: $e');
        log('$stackTrace');

        state = state.copyWith(
          isLoading: false,
          error: 'Login response could not be processed: $e',
        );

        return false;
      }
    }

    state = state.copyWith(
      isLoading: false,
      error: 'Login failed after multiple attempts.',
    );

    return false;
  }

  // --------------------------------------------------
  // REGISTER
  // --------------------------------------------------

  Future<bool> register(
    String email,
    String password,
    String fullName,
  ) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      await apiClient.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName,
          'role': 'employee',
        },
      );

      state = state.copyWith(
        isLoading: false,
        error: null,
      );

      return true;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      String message = 'Registration failed.';

      if (responseData is Map<String, dynamic> &&
          responseData['detail'] != null) {
        message = responseData['detail'].toString();
      }

      state = state.copyWith(
        isLoading: false,
        error: message,
      );

      return false;
    } catch (e, stackTrace) {
      log('Registration processing failed: $e');
      log('$stackTrace');

      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );

      return false;
    }
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> logout() async {
    _tokenRefreshTimer?.cancel();
    _expirationCheckTimer?.cancel();

    _tokenRefreshTimer = null;
    _expirationCheckTimer = null;

    try {
      await apiClient.clearAuthTokens();

      _authBox ??= await Hive.openBox<String>('auth');
      await _authBox?.clear();
    } catch (e, stackTrace) {
      log('Logout storage cleanup failed: $e');
      log('$stackTrace');
    }

    state = AuthState();

    log('Logged out.');
  }

  // --------------------------------------------------
  // CREATE EMPLOYEE (ADMIN)
  // --------------------------------------------------

  Future<Map<String, dynamic>> createEmployee({
    required Map<String, dynamic> employee,
    Map<String, dynamic>? user,
  }) async {
    final Map<String, dynamic> payload = {
      'employee': employee,
    };

    if (user != null) {
      payload['user'] = user;
    }

    final response = await apiClient.post(
      '/admin/create-user',
      data: payload,
    );

    final data = response.data;

    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Create employee response must be a JSON object.',
      );
    }

    return data;
  }

  // --------------------------------------------------
  // CLEANUP
  // --------------------------------------------------

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _expirationCheckTimer?.cancel();
    super.dispose();
  }
}

// --------------------------------------------------
// PROVIDERS
// --------------------------------------------------

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});