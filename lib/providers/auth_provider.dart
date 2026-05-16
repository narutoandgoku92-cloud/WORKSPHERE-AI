// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// Authentication state
class AuthState {
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Authentication provider
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;

  AuthNotifier(this.apiClient) : super(AuthState()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final authBox = await Hive.openBox<String>('auth');
      final token = authBox.get('access_token');
      if (token != null) {
        state = state.copyWith(accessToken: token);
      }
    } catch (e) {
      print('Error initializing auth: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('[AuthNotifier] 🔐 Login attempt for $email');
      
      final response = await apiClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      print('[AuthNotifier] ✓ Login successful, status: ${response.statusCode}');
      
      final data = LoginResponse.fromJson(response.data);
      
      apiClient.setAuthToken(data.accessToken);
      
      final authBox = await Hive.openBox<String>('auth');
      await authBox.put('refresh_token', data.refreshToken);

      state = state.copyWith(
        user: data.user,
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        isLoading: false,
        error: null,
      );

      print('[AuthNotifier] ✓ User authenticated: ${data.user.email}');
      return true;
    } on DioException catch (e) {
      print('[AuthNotifier] ❌ Login failed (Dio error)');
      print('[AuthNotifier] Error type: ${e.type}');
      print('[AuthNotifier] Status code: ${e.response?.statusCode}');
      print('[AuthNotifier] Message: ${e.message}');
      print('[AuthNotifier] Response: ${e.response?.data}');
      
      String errorMsg = 'Login failed';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection timeout - check your API URL and network connection';
      } else if (e.type == DioExceptionType.unknown && e.message?.contains('SocketException') == true) {
        errorMsg = 'Network error - cannot reach backend server';
      } else if (e.response?.statusCode == 401) {
        errorMsg = 'Invalid credentials';
      } else if (e.response?.statusCode == 403) {
        errorMsg = 'User account is disabled';
      } else {
        errorMsg = e.response?.data['detail'] ?? e.message ?? errorMsg;
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
      return false;
    } catch (e) {
      print('[AuthNotifier] ❌ Login failed (unexpected error): ${e.toString()}');
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await apiClient.clearAuthToken();
    final authBox = await Hive.openBox<String>('auth');
    await authBox.clear();
    state = AuthState();
  }

  Future<bool> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: ${e.toString()}',
      );
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

// Auth state selectors
final isAuthenticatedProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.accessToken != null;
});

final currentUserProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.user;
});
