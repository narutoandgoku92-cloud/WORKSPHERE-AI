import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// ----------------------------
/// AUTH STATE
/// ----------------------------
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

/// ----------------------------
/// AUTH NOTIFIER
/// ----------------------------
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

  /// ----------------------------
  /// INIT LOCAL SESSION
  /// ----------------------------
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
      print("AUTH INIT ERROR: $e");
    }
  }

  Box<String> get _box => _authBox!;

  /// ----------------------------
  /// LOGIN (FIXED + SAFE)
  /// ----------------------------
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await apiClient.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );

      print("LOGIN RESPONSE: ${res.data}");

      final data = res.data;

      final access = data['access_token'] ??
          data['accessToken'] ??
          data['token'];

      final refresh = data['refresh_token'] ??
          data['refreshToken'];

      final userData = data['user'] ?? data['data']?['user'];

      if (access == null || refresh == null || userData == null) {
        throw Exception("Invalid backend response format");
      }

      final user = User.fromJson(userData);

      final expires = DateTime.now().add(
        Duration(seconds: data['expires_in'] ?? 900),
      );

      await (_authBox ??= await Hive.openBox<String>('auth')).put(
        'access_token',
        access,
      );
      await _authBox!.put('refresh_token', refresh);
      await _authBox!.put('user', jsonEncode(userData));
      await _authBox!.put('token_expires_at', expires.toIso8601String());

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
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );

      print("LOGIN ERROR: $e");
      return false;
    }
  }

  /// ----------------------------
  /// REGISTER
  /// ----------------------------
  Future<bool> register(
      String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);

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

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// ----------------------------
  /// REFRESH TOKEN
  /// ----------------------------
  Future<void> _refreshAccessToken() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final refreshToken = state.refreshToken;

      if (refreshToken == null) {
        throw Exception("Missing refresh token");
      }

      final res = await apiClient.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = res.data;

      final newAccess = data['access_token'];
      final newRefresh = data['refresh_token'] ?? refreshToken;

      final expires = DateTime.now().add(
        Duration(seconds: data['expires_in'] ?? 900),
      );

      await _box.put('access_token', newAccess);
      await _box.put('refresh_token', newRefresh);
      await _box.put('token_expires_at', expires.toIso8601String());

      apiClient.setAuthTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      state = state.copyWith(
        accessToken: newAccess,
        refreshToken: newRefresh,
        tokenExpiresAt: expires,
        isTokenExpired: false,
      );

      _startTimers();
    } catch (e) {
      print("REFRESH ERROR: $e");
      await logout();
    } finally {
      _isRefreshing = false;
    }
  }

  /// ----------------------------
  /// LOGOUT
  /// ----------------------------
  Future<void> logout() async {
    try {
      _refreshTimer?.cancel();
      _expirationTimer?.cancel();

      await apiClient.clearAuthTokens();

      final box = await Hive.openBox<String>('auth');
      await box.clear();

      state = AuthState();
    } catch (e) {
      print("LOGOUT ERROR: $e");
    }
  }

  /// ----------------------------
  /// TIMERS
  /// ----------------------------
  void _startTimers() {
    _refreshTimer?.cancel();
    _expirationTimer?.cancel();

    final exp = state.tokenExpiresAt;
    if (exp == null) return;

    final refreshAt =
        exp.subtract(Duration(minutes: _refreshBeforeMinutes));

    final duration = refreshAt.difference(DateTime.now());

    if (duration.isNegative) {
      _refreshAccessToken();
    } else {
      _refreshTimer = Timer(duration, _refreshAccessToken);
    }

    _expirationTimer =
        Timer.periodic(Duration(seconds: _checkIntervalSeconds), (_) {
      final exp = state.tokenExpiresAt;
      if (exp != null && DateTime.now().isAfter(exp)) {
        logout();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}

/// ----------------------------
/// PROVIDERS
/// ----------------------------
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthNotifier(api);
});

final isAuthenticatedProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.accessToken != null &&
      auth.accessToken!.isNotEmpty;
});