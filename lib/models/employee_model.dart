// lib/models/employee_model.dart

class Employee {
  final String id;
  final String employeeId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final double salaryPerHour;
  final String status;
  final bool isVerified;
  final DateTime? hireDate;
  final DateTime createdAt;

  Employee({
    required this.id,
    required this.employeeId,
    required this.fullName,
    this.email,
    this.phone,
    this.jobTitle,
    required this.salaryPerHour,
    required this.status,
    required this.isVerified,
    this.hireDate,
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      jobTitle: json['job_title'],
      salaryPerHour: (json['salary_per_hour'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'active',
      isVerified: json['is_verified'] ?? false,
      hireDate: json['hire_date'] != null ? DateTime.parse(json['hire_date']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'job_title': jobTitle,
      'salary_per_hour': salaryPerHour,
      'status': status,
      'is_verified': isVerified,
      'hire_date': hireDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
