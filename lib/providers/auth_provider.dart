// lib/providers/auth_provider.dart

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// Authentication state
class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
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
      await apiClient.initialize();
      final isAuthenticated = await apiClient.hasAccessToken();

      final authBox = await Hive.openBox<String>('auth');
      final userJson = authBox.get('user');
      final user = userJson != null ? User.fromJson(jsonDecode(userJson)) : null;

      state = state.copyWith(
        isAuthenticated: isAuthenticated,
        user: user,
      );
    } catch (e) {
      print('Error initializing auth: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = LoginResponse.fromJson(response.data);
      
      await apiClient.setAuthTokens(
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
      );
      
      final authBox = await Hive.openBox<String>('auth');
      await authBox.put('user', jsonEncode(data.user.toJson()));

      state = state.copyWith(
        user: data.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await apiClient.clearAuthTokens();
    final authBox = await Hive.openBox<String>('auth');
    await authBox.clear();
    state = AuthState();
  }

  Future<Map<String, dynamic>> createEmployee({
    required Map<String, dynamic> employee,
    Map<String, dynamic>? user,
  }) async {
    try {
      final payload = {"employee": employee};
      if (user != null) payload['user'] = user;

      final response = await apiClient.post('/admin/create-user', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to create employee: $e');
    }
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
  return auth.isAuthenticated;
});

final currentUserProvider = Provider((ref) {
  final auth = ref.watch(authProvider);
  return auth.user;
});
