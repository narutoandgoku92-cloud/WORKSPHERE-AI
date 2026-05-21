import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// --------------------
/// AUTH STATE - IMPROVED with expiration tracking
/// --------------------
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

/// --------------------
/// AUTH CONTROLLER - IMPROVED with expiration & auto-refresh
/// --------------------
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;
  Timer? _tokenRefreshTimer;
  Timer? _expirationCheckTimer;
  Box<String>? _authBox;

  static const int _tokenRefreshMinutesBefore = 5;
  static const int _expirationCheckIntervalSeconds = 60;

  AuthNotifier(this.apiClient) : super(AuthState()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await apiClient.initialize();

      _authBox = await Hive.openBox<String>('auth');
      final userStr = _authBox?.get('user');
      final accessTokenStr = _authBox?.get('access_token');
      final refreshTokenStr = _authBox?.get('refresh_token');
      final expiresAtStr = _authBox?.get('token_expires_at');

      User? user;
      if (userStr != null) {
        user = User.fromJson(jsonDecode(userStr));
      }

      DateTime? expiresAt;
      if (expiresAtStr != null) {
        try {
          expiresAt = DateTime.parse(expiresAtStr);
        } catch (e) {
          log('⚠️ Failed to parse token expiration: $e');
        }
      }

      if (accessTokenStr != null && accessTokenStr.isNotEmpty) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          accessToken: accessTokenStr,
          refreshToken: refreshTokenStr,
          tokenExpiresAt: expiresAt,
        );

        // Set up refresh timers
        _setupTokenRefreshTimer();
        _setupExpirationCheckTimer();
      }
    } catch (e) {
      log('❌ Auth initialization failed: $e');
    }
  }

  void _setupTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();

    if (state.tokenExpiresAt == null) return;

    final now = DateTime.now();
    final expiresAt = state.tokenExpiresAt!;
    final refreshAt = expiresAt.subtract(Duration(minutes: _tokenRefreshMinutesBefore));

    final duration = refreshAt.difference(now);

    if (duration.isNegative) {
      log('⚠️ Token expiring soon, refreshing immediately');
      _refreshAccessToken();
      return;
    }

    log('⏰ Token refresh scheduled in ${duration.inMinutes} minutes');

    _tokenRefreshTimer = Timer(duration, () {
      log('🔄 Token refresh timer triggered');
      _refreshAccessToken();
    });
  }

  void _setupExpirationCheckTimer() {
    _expirationCheckTimer?.cancel();

    _expirationCheckTimer = Timer.periodic(
      Duration(seconds: _expirationCheckIntervalSeconds),
      (_) {
        if (state.tokenExpiresAt != null) {
          final now = DateTime.now();
          final expiresAt = state.tokenExpiresAt!;

          if (now.isAfter(expiresAt)) {
            log('⏰ Token expired, logging out');
            logout();
          } else if (!state.isTokenExpired) {
            final timeUntilExpire = expiresAt.difference(now);
            if (timeUntilExpire.inMinutes <= _tokenRefreshMinutesBefore) {
              log('⚠️ Token expiring in ${timeUntilExpire.inMinutes} minutes');
              _setupTokenRefreshTimer();
            }
          }
        }
      },
    );
  }

  Future<void> _refreshAccessToken() async {
    if (state.refreshToken == null || state.refreshToken!.isEmpty) {
      log('❌ No refresh token available');
      await logout();
      return;
    }

    try {
      log('🔄 Refreshing access token...');

      final response = await apiClient.post(
        '/auth/refresh',  // FIXED: removed /api/v1 prefix
        data: {'refresh_token': state.refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;
      final expiresIn = response.data['expires_in'] as int? ?? 900;

      if (newAccessToken == null) {
        throw Exception('Missing access_token in refresh response');
      }

      final newExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await apiClient.setAuthTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? state.refreshToken!,
      );

      _authBox?.put('access_token', newAccessToken);
      if (newRefreshToken != null) {
        _authBox?.put('refresh_token', newRefreshToken);
      }
      _authBox?.put('token_expires_at', newExpiresAt.toIso8601String());

      state = state.copyWith(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? state.refreshToken,
        tokenExpiresAt: newExpiresAt,
        isTokenExpired: false,
      );

      log('✅ Token refreshed successfully');
      _setupTokenRefreshTimer();

    } on DioException catch (e) {
      log('❌ Token refresh failed (${e.response?.statusCode}): ${e.response?.data}');
      await logout();
    } catch (e) {
      log('❌ Token refresh error: $e');
      await logout();
    }
  }

  /// --------------------
  /// LOGIN (WITH RETRY)
  /// --------------------
  Future<bool> login(String email, String password, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      state = state.copyWith(isLoading: true, error: null);

      try {
        log('📝 Login attempt $attempt/$maxRetries for $email');

        final response = await apiClient.post(
          '/auth/login',
          data: {'email': email, 'password': password},
        );

        final data = response.data;
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userData = data['user'];
        final expiresIn = data['expires_in'] as int? ?? 900;

        if (accessToken == null || refreshToken == null) {
          throw Exception('Missing tokens in response');
        }

        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await apiClient.setAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        _authBox = await Hive.openBox<String>('auth');
        await _authBox?.put('user', jsonEncode(userData));
        await _authBox?.put('access_token', accessToken);
        await _authBox?.put('refresh_token', refreshToken);
        await _authBox?.put('token_expires_at', expiresAt.toIso8601String());

        state = state.copyWith(
          user: User.fromJson(userData),
          isAuthenticated: true,
          isLoading: false,
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenExpiresAt: expiresAt,
        );

        log('✅ Login successful');

        // Set up auto-refresh
        _setupTokenRefreshTimer();
        _setupExpirationCheckTimer();

        return true;

      } on DioException catch (e) {
        final errorMessage = e.response?.data?['detail'] ?? e.message ?? 'Login failed';
        log('❌ Login attempt $attempt failed: $errorMessage');

        if (attempt < maxRetries) {
          final delayMs = 500 * attempt;
          log('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          state = state.copyWith(
            isLoading: false,
            error: errorMessage.toString(),
          );
          return false;
        }

      } catch (e) {
        log('❌ Login error: $e');

        if (attempt < maxRetries) {
          final delayMs = 500 * attempt;
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          state = state.copyWith(isLoading: false, error: 'Login failed: $e');
          return false;
        }
      }
    }

    return false;
  }

  /// --------------------
  /// REGISTER
  /// --------------------
  Future<bool> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true);

    try {
      await apiClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': 'employee',
        },
      );

      state = state.copyWith(isLoading: false);
      return true;

    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] ?? 'Registration failed',
      );
      return false;

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// --------------------
  /// LOGOUT
  /// --------------------
  Future<void> logout() async {
    _tokenRefreshTimer?.cancel();
    _expirationCheckTimer?.cancel();

    await apiClient.clearAuthTokens();
    _authBox?.clear();

    state = AuthState();
    log('✅ Logged out successfully');
  }

  /// --------------------
  /// CREATE EMPLOYEE (ADMIN)
  /// --------------------
  Future<Map<String, dynamic>> createEmployee({
    required Map<String, dynamic> employee,
    Map<String, dynamic>? user,
  }) async {
    final payload = {'employee': employee};
    if (user != null) payload['user'] = user;

    final res = await apiClient.post('/admin/create-user', data: payload);
    return res.data;
  }
}

/// --------------------
/// PROVIDERS
/// --------------------
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

final isAuthenticatedProvider = Provider((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider((ref) {
  return ref.watch(authProvider).user;
});