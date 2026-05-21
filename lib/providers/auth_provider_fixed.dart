import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// Authentication state
class AuthState {
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;
  final bool isTokenExpired;
  final DateTime? tokenExpiresAt;

  AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
    this.isTokenExpired = false,
    this.tokenExpiresAt,
  });

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    String? error,
    bool? isTokenExpired,
    DateTime? tokenExpiresAt,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isTokenExpired: isTokenExpired ?? this.isTokenExpired,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;

  Timer? _refreshTimer;
  Timer? _expirationTimer;
  Box<String>? _authBox;
  bool _isRefreshing = false;

  static const int _refreshBeforeMinutes = 5;
  static const int _checkIntervalSeconds = 60;

  AuthNotifier(this.apiClient) : super(AuthState()) {
    _init();
  }

  // ----------------------------
  // SAFE HIVE ACCESS
  // ----------------------------
  Future<Box<String>> get _box async {
    return _authBox ??= await Hive.openBox<String>('auth');
  }

  Future<void> _init() async {
    try {
      _authBox = await Hive.openBox<String>('auth');

      final access = _authBox!.get('access_token');
      final refresh = _authBox!.get('refresh_token');
      final userJson = _authBox!.get('user');
      final expires = _authBox!.get('token_expires_at');

      if (access != null) {
        state = state.copyWith(
          accessToken: access,
          refreshToken: refresh,
          user: userJson != null ? User.fromJson(jsonDecode(userJson)) : null,
          tokenExpiresAt:
              expires != null ? DateTime.tryParse(expires) : null,
        );

        _startTimers();
      }
    } catch (e) {
      print('Auth init error: $e');
    }
  }

  // ----------------------------
  // TIMERS
  // ----------------------------
  void _startTimers() {
    _startRefreshTimer();
    _startExpirationTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    final exp = state.tokenExpiresAt;
    if (exp == null) return;

    final refreshAt =
        exp.subtract(Duration(minutes: _refreshBeforeMinutes));
    final duration = refreshAt.difference(DateTime.now());

    if (duration.isNegative) {
      _refreshAccessToken();
      return;
    }

    _refreshTimer = Timer(duration, _refreshAccessToken);
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();

    _expirationTimer =
        Timer.periodic(Duration(seconds: _checkIntervalSeconds), (_) {
      final exp = state.tokenExpiresAt;
      if (exp == null) return;

      if (DateTime.now().isAfter(exp)) {
        logout();
      }
    });
  }

  // ----------------------------
  // REFRESH TOKEN (SAFE)
  // ----------------------------
  Future<void> _refreshAccessToken() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final refreshToken = state.refreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception("Missing refresh token");
      }

      final res = await apiClient.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccess = res.data['access_token'] as String;
      final newRefresh = res.data['refresh_token'] as String?;
      final expiresIn = res.data['expires_in'] as int? ?? 900;

      final finalRefresh = newRefresh ?? refreshToken;

      final newExp =
          DateTime.now().add(Duration(seconds: expiresIn));

      apiClient.setAuthTokens(
        accessToken: newAccess,
        refreshToken: finalRefresh,
      );

      final box = await _box;

      await box.put('access_token', newAccess);
      await box.put('refresh_token', finalRefresh);
      await box.put('token_expires_at', newExp.toIso8601String());

      state = state.copyWith(
        accessToken: newAccess,
        refreshToken: finalRefresh,
        tokenExpiresAt: newExp,
        isTokenExpired: false,
      );

      _startRefreshTimer();
    } catch (e) {
      print('Refresh failed: $e');
      await logout();
    } finally {
      _isRefreshing = false;
    }
  }

  // ----------------------------
  // LOGIN
  // ----------------------------
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final res = await apiClient.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = res.data;

      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      final user = User.fromJson(data['user']);

      final expires =
          DateTime.now().add(Duration(seconds: data['expires_in'] ?? 900));

      final box = await _box;

      await box.put('access_token', access);
      await box.put('refresh_token', refresh);
      await box.put('user', jsonEncode(data['user']));
      await box.put('token_expires_at', expires.toIso8601String());

      apiClient.setAuthTokens(
        accessToken: access,
        refreshToken: refresh,
      );

      state = state.copyWith(
        user: user,
        accessToken: access,
        refreshToken: refresh,
        tokenExpiresAt: expires,
        isLoading: false,
      );

      _startTimers();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ----------------------------
  // REGISTER
  // ----------------------------
  Future<bool> register(
      String email, String password, String fullName) async {
    try {
      await apiClient.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': 'employee',
        },
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ----------------------------
  // LOGOUT
  // ----------------------------
  Future<void> logout() async {
    try {
      _refreshTimer?.cancel();
      _expirationTimer?.cancel();

      await apiClient.clearAuthTokens();

      final box = await _box;
      await box.clear();

      state = AuthState();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}

// ----------------------------
// PROVIDERS
// ----------------------------
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthNotifier(api);
});

final isAuthenticatedProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.accessToken != null;
});