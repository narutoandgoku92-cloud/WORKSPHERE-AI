// lib/services/payroll_service.dart

import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/payroll_model.dart';

class PayrollService {
  PayrollService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PayrollEmployee>> fetchEmployees() async {
    final response = await _apiClient.get('/employees', queryParameters: {'skip': 0, 'limit': 100});
    final rawList = response.data as List<dynamic>?;
    if (rawList == null) return [];

    return rawList
        .map((item) => PayrollEmployee.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PayrollTransaction>> fetchTransactions() async {
    final response = await _apiClient.get('/payroll/transactions', queryParameters: {'skip': 0, 'limit': 100});
    final rawList = response.data as List<dynamic>?;
    if (rawList == null) return [];

    return rawList
        .map((item) => PayrollTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> processSalary(
    String employeeId,
    DateTime periodStart,
    DateTime periodEnd,
    String bankName,
    String accountHolderName,
    String accountNumber,
    String routingNumber, {
    String currency = 'USD',
    String? description,
  }) async {
    final data = {
      'employee_id': employeeId,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'currency': currency,
      'bank_details': {
        'bank_name': bankName,
        'account_holder_name': accountHolderName,
        'account_number': accountNumber,
        'routing_number': routingNumber,
      },
      if (description != null) 'description': description,
    };

    final response = await _apiClient.post('/payroll/process-salary', data: data);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<List<PayrollPayoutResult>> bulkPay(
    List<String> employeeIds,
    DateTime periodStart,
    DateTime periodEnd,
    String bankName,
    String accountHolderName,
    String accountNumber,
    String routingNumber, {
    String currency = 'USD',
    String? description,
  }) async {
    final payouts = employeeIds
        .map((employeeId) => {
              'employee_id': employeeId,
              'period_start': periodStart.toIso8601String(),
              'period_end': periodEnd.toIso8601String(),
              'currency': currency,
              'bank_details': {
                'bank_name': bankName,
                'account_holder_name': accountHolderName,
                'account_number': accountNumber,
                'routing_number': routingNumber,
              },
              if (description != null) 'description': description,
            })
        .toList();

    final response = await _apiClient.post('/payroll/bulk-pay', data: {'payouts': payouts});
    final rawList = response.data as List<dynamic>?;
    if (rawList == null) return [];
    return rawList
        .map((item) => PayrollPayoutResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
