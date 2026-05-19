# CRITICAL FIX #5: Flutter Token Refresh & Offline Support
# lib/providers/auth_provider_fixed.dart - Production-ready auth with token refresh

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// Authentication state with complete session management
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

/// Production-ready authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;
  Timer? _refreshTimer;
  Timer? _expirationCheckTimer;
  Box<String>? _authBox;
  
  // Configuration
  static const int _tokenRefreshMinutesBefore = 5; // Refresh 5 minutes before expiration
  static const int _expirationCheckIntervalSeconds = 60; // Check every minute

  AuthNotifier(this.apiClient) : super(AuthState()) {
    _initializeAuth();
  }

  /// Initialize authentication from local storage
  Future<void> _initializeAuth() async {
    try {
      _authBox = await Hive.openBox<String>('auth');
      
      final accessToken = _authBox?.get('access_token');
      final refreshToken = _authBox?.get('refresh_token');
      final userJson = _authBox?.get('user');
      final expiresAtStr = _authBox?.get('token_expires_at');
      
      if (accessToken != null) {
        User? user;
        if (userJson != null) {
          try {
            user = User.fromJson(jsonDecode(userJson));
          } catch (e) {
            print('Error decoding user: $e');
          }
        }
        
        DateTime? expiresAt;
        if (expiresAtStr != null) {
          try {
            expiresAt = DateTime.parse(expiresAtStr);
          } catch (e) {
            print('Error parsing expiration time: $e');
          }
        }
        
        state = state.copyWith(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
          tokenExpiresAt: expiresAt,
        );
        
        // Set up refresh timer
        _setupTokenRefreshTimer();
        _setupExpirationCheckTimer();
      }
    } catch (e) {
      print('Error initializing auth: $e');
    }
  }

  /// Set up timer to refresh token before expiration
  void _setupTokenRefreshTimer() {
    _refreshTimer?.cancel();
    
    if (state.tokenExpiresAt == null) return;
    
    final now = DateTime.now();
    final expiresAt = state.tokenExpiresAt!;
    final refreshAt = expiresAt.subtract(
      Duration(minutes: _tokenRefreshMinutesBefore)
    );
    
    final duration = refreshAt.difference(now);
    
    if (duration.isNegative) {
      // Token already expired or will expire within refresh window
      print('Token expiring soon, refreshing immediately');
      _refreshAccessToken();
      return;
    }
    
    print('Token refresh scheduled in ${duration.inMinutes} minutes');
    
    _refreshTimer = Timer(duration, () {
      print('Token refresh triggered');
      _refreshAccessToken();
    });
  }

  /// Set up periodic check for token expiration
  void _setupExpirationCheckTimer() {
    _expirationCheckTimer?.cancel();
    
    _expirationCheckTimer = Timer.periodic(
      Duration(seconds: _expirationCheckIntervalSeconds),
      (_) {
        if (state.tokenExpiresAt != null) {
          final now = DateTime.now();
          final expiresAt = state.tokenExpiresAt!;
          
          if (now.isAfter(expiresAt)) {
            print('Token expired, logging out');
            logout();
          } else if (state.isTokenExpired == false) {
            final timeUntilExpire = expiresAt.difference(now);
            if (timeUntilExpire.inMinutes <= _tokenRefreshMinutesBefore) {
              print('Token expiring in ${timeUntilExpire.inMinutes} minutes');
              _setupTokenRefreshTimer();
            }
          }
        }
      },
    );
  }

  /// Refresh access token using refresh token
  Future<void> _refreshAccessToken() async {
    try {
      if (state.refreshToken == null) {
        print('No refresh token available');
        await logout();
        return;
      }
      
      final response = await apiClient.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': state.refreshToken},
      );
      
      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String?;
      final expiresIn = response.data['expires_in'] as int? ?? 900; // Default 15 minutes
      
      // Calculate new expiration time
      final newExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      
      // Update tokens
      apiClient.setAuthToken(newAccessToken);
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
      
      print('✅ Token refreshed successfully');
      
      // Reset refresh timer
      _setupTokenRefreshTimer();
    
    } catch (e) {
      print('❌ Token refresh failed: $e');
      // If refresh fails, logout user
      await logout();
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      final data = response.data;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      final userJson = jsonEncode(data['user']);
      
      // Calculate token expiration (15 minutes by default)
      final expiresIn = data['expires_in'] as int? ?? 900;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      
      // Save to local storage
      apiClient.setAuthToken(accessToken);
      _authBox = await Hive.openBox<String>('auth');
      await _authBox?.put('access_token', accessToken);
      await _authBox?.put('refresh_token', refreshToken);
      await _authBox?.put('user', userJson);
      await _authBox?.put('token_expires_at', expiresAt.toIso8601String());
      
      // Parse user
      final user = User.fromJson(data['user']);
      
      state = state.copyWith(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiresAt: expiresAt,
        isLoading: false,
        error: null,
      );
      
      // ✅ Start token refresh timer
      _setupTokenRefreshTimer();
      _setupExpirationCheckTimer();
      
      print('✅ Login successful');
      return true;
    
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Login failed';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage.toString(),
      );
      print('❌ Login failed: $errorMessage');
      return false;
    
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: ${e.toString()}',
      );
      print('❌ Login error: $e');
      return false;
    }
  }

  /// Register new account
  Future<bool> register(String email, String password, String fullName) async {
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
      
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
      
      print('✅ Registration successful');
      return true;
    
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Registration failed';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage.toString(),
      );
      print('❌ Registration failed: $errorMessage');
      return false;
    
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: ${e.toString()}',
      );
      print('❌ Registration error: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Call logout endpoint to blacklist token
      if (state.accessToken != null) {
        try {
          await apiClient.post(
            '/api/v1/auth/logout',
            options: Options(
              headers: {
                'Authorization': 'Bearer ${state.accessToken}',
              },
            ),
          );
        } catch (e) {
          print('Logout API call failed: $e (continuing with local logout)');
        }
      }
      
      // Clear tokens
      await apiClient.clearAuthToken();
      _authBox = await Hive.openBox<String>('auth');
      await _authBox?.clear();
      
      // Cancel timers
      _refreshTimer?.cancel();
      _expirationCheckTimer?.cancel();
      
      // Clear state
      state = AuthState();
      
      print('✅ Logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _expirationCheckTimer?.cancel();
    super.dispose();
  }
}

/// Create the auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

/// Selector providers
final isAuthenticatedProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.accessToken != null && !(auth.isTokenExpired);
});

final currentUserProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.user;
});

final isTokenRefreshingProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  final expiresAt = auth.tokenExpiresAt;
  
  if (expiresAt == null) return false;
  
  final now = DateTime.now();
  final minutesUntilExpire = expiresAt.difference(now).inMinutes;
  
  return minutesUntilExpire <= 5; // Will refresh soon
});
