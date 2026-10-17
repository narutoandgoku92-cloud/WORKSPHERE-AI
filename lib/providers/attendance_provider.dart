
 // lib/providers/attendance_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

// ============================================================
// ADMIN ATTENDANCE STATISTICS + CHECK-IN/CHECK-OUT
// ============================================================

class AttendanceNotifier
    extends StateNotifier<AsyncValue<AttendanceStats?>> {
  final ApiClient apiClient;

  AttendanceNotifier(this.apiClient)
      : super(const AsyncValue.loading());

  /// Fetch workforce-wide attendance statistics.
  /// This endpoint is intended for administrators.
  Future<void> fetchTodayStats() async {
    try {
      state = const AsyncValue.loading();

      final response = await apiClient.get('/attendance/today');
      final stats = AttendanceStats.fromJson(response.data);

      state = AsyncValue.data(stats);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Check in the authenticated employee.
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
    } catch (error) {
      print('Check-in error: $error');
      return false;
    }
  }

  /// Check out the authenticated employee.
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
    } catch (error) {
      print('Check-out error: $error');
      return false;
    }
  }
}

/// Existing provider used by the admin dashboard and check-in screen.
/// Keep this provider name unchanged to preserve existing references.
final attendanceProvider = StateNotifierProvider<
    AttendanceNotifier, AsyncValue<AttendanceStats?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = AttendanceNotifier(apiClient);

  notifier.fetchTodayStats();

  return notifier;
});

// ============================================================
// EMPLOYEE PERSONAL ATTENDANCE HISTORY
// ============================================================

class EmployeeAttendanceNotifier
    extends StateNotifier<AsyncValue<List<AttendanceLog>>> {
  final ApiClient apiClient;

  EmployeeAttendanceNotifier(this.apiClient)
      : super(const AsyncValue.loading());

  /// Fetch the authenticated employee's attendance history.
  Future<void> fetchMyAttendance() async {
    state = const AsyncValue.loading();

    try {
      final response = await apiClient.get('/attendance/me?days=30');
      final data = response.data;

      if (data is! List) {
        throw const FormatException(
          'Unexpected response from attendance history endpoint.',
        );
      }

      final logs = data.map((item) {
        return AttendanceLog.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();

      state = AsyncValue.data(logs);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Separate provider for the employee dashboard.
/// Does not change the admin statistics provider.
final employeeAttendanceProvider = StateNotifierProvider<
    EmployeeAttendanceNotifier,
    AsyncValue<List<AttendanceLog>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = EmployeeAttendanceNotifier(apiClient);

  notifier.fetchMyAttendance();

  return notifier;
});
