// lib/models/payroll_model.dart

class PayrollEmployee {
  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String jobTitle;
  final double salaryPerHour;
  final String deptId;
  final String status;

  PayrollEmployee({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.jobTitle,
    required this.salaryPerHour,
    required this.deptId,
    required this.status,
  });

  factory PayrollEmployee.fromJson(Map<String, dynamic> json) {
    return PayrollEmployee(
      id: json['id'] ?? json['employee_id'] ?? '',
      employeeId: json['employee_id'] ?? json['id'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      jobTitle: json['job_title'] ?? json['jobTitle'] ?? '',
      salaryPerHour: (json['salary_per_hour'] as num?)?.toDouble() ?? 0.0,
      deptId: json['dept_id'] ?? json['department_id'] ?? '',
      status: json['status'] ?? 'active',
    );
  }

  double get dailyRate => salaryPerHour * 8;
  double get estimatedMonthlySalary => dailyRate * 20;
}

class PayrollTransaction {
  final String id;
  final String employeeId;
  final String payrollRecordId;
  final String externalTransactionId;
  final String status;
  final double amount;
  final String currency;
  final String provider;
  final String? failureReason;
  final Map<String, dynamic>? details;

  PayrollTransaction({
    required this.id,
    required this.employeeId,
    required this.payrollRecordId,
    required this.externalTransactionId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.provider,
    this.failureReason,
    this.details,
  });

  factory PayrollTransaction.fromJson(Map<String, dynamic> json) {
    return PayrollTransaction(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      payrollRecordId: json['payroll_record_id'] ?? '',
      externalTransactionId: json['external_transaction_id'] ?? '',
      status: json['status'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      provider: json['provider'] ?? 'squad',
      failureReason: json['failure_reason']?.toString(),
      details: json['details'] is Map<String, dynamic> ? json['details'] : null,
    );
  }
}

class PayrollPayoutResult {
  final String employeeId;
  final String transactionId;
  final String status;
  final double amount;
  final String currency;
  final String message;

  PayrollPayoutResult({
    required this.employeeId,
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.message,
  });

  factory PayrollPayoutResult.fromJson(Map<String, dynamic> json) {
    return PayrollPayoutResult(
      employeeId: json['employee_id'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      status: json['status'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      message: json['message'] ?? '',
    );
  }
}
