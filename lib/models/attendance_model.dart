// lib/models/attendance_model.dart

class AttendanceLog {
  final String id;
  final String employeeId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final bool checkInVerified;
  final bool gpsVerified;
  final String checkInMethod;

  AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    required this.checkInVerified,
    required this.gpsVerified,
    required this.checkInMethod,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      checkInTime: DateTime.parse(json['check_in_time'] ?? DateTime.now().toIso8601String()),
      checkOutTime: json['check_out_time'] != null ? DateTime.parse(json['check_out_time']) : null,
      checkInLatitude: (json['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num?)?.toDouble(),
      checkInVerified: json['check_in_verified'] ?? false,
      gpsVerified: json['gps_verified'] ?? false,
      checkInMethod: json['check_in_method'] ?? 'face',
    );
  }

  double getHoursWorked() {
    if (checkOutTime == null) return 0;
    return checkOutTime!.difference(checkInTime).inSeconds / 3600;
  }

  String getStatus() {
    if (checkOutTime != null) return 'Checked Out';
    return 'Checked In';
  }
}

class AttendanceStats {
  final int totalEmployees;
  final int presentToday;
  final int absentToday;
  final int lateToday;
  final int checkedInCount;
  final int checkedOutCount;

  AttendanceStats({
    required this.totalEmployees,
    required this.presentToday,
    required this.absentToday,
    required this.lateToday,
    required this.checkedInCount,
    required this.checkedOutCount,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalEmployees: json['total_employees'] ?? 0,
      presentToday: json['present_today'] ?? 0,
      absentToday: json['absent_today'] ?? 0,
      lateToday: json['late_today'] ?? 0,
      checkedInCount: json['checked_in_count'] ?? 0,
      checkedOutCount: json['checked_out_count'] ?? 0,
    );
  }
}
