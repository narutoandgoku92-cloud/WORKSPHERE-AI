// lib/providers/attendance_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class AttendanceNotifier extends StateNotifier<AsyncValue<AttendanceStats?>> {
  final ApiClient apiClient;

  AttendanceNotifier(this.apiClient) : super(const AsyncValue.loading());

  Future<void> fetchTodayStats() async {
    try {
      state = const AsyncValue.loading();
      final response = await apiClient.get('/attendance/today');
      final stats = AttendanceStats.fromJson(response.data);
      state = AsyncValue.data(stats);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> checkIn(double latitude, double longitude) async {
    try {
      await apiClient.post(
        '/attendance/check-in',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'check_in_method': 'face',
        },
      );
      await fetchTodayStats();
      return true;
    } catch (e) {
      print('Check-in error: $e');
      return false;
    }
  }

  Future<bool> checkOut(double latitude, double longitude) async {
    try {
      await apiClient.post(
        '/attendance/check-out',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      await fetchTodayStats();
      return true;
    } catch (e) {
      print('Check-out error: $e');
      return false;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<AttendanceStats?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = AttendanceNotifier(apiClient);
  notifier.fetchTodayStats();
  return notifier;
});
