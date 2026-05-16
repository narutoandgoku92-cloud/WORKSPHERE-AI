// lib/providers/payroll_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payroll_service.dart';
import '../models/payroll_model.dart';
import 'auth_provider.dart';

final payrollServiceProvider = Provider<PayrollService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PayrollService(apiClient);
});

final payrollProvider = StateNotifierProvider<PayrollNotifier, PayrollState>((ref) {
  final service = ref.watch(payrollServiceProvider);
  return PayrollNotifier(service);
});

class PayrollState {
  final List<PayrollEmployee> employees;
  final List<PayrollTransaction> transactions;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? message;

  PayrollState({
    this.employees = const [],
    this.transactions = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.message,
  });

  PayrollState copyWith({
    List<PayrollEmployee>? employees,
    List<PayrollTransaction>? transactions,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? message,
  }) {
    return PayrollState(
      employees: employees ?? this.employees,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      message: message,
    );
  }
}

class PayrollNotifier extends StateNotifier<PayrollState> {
  PayrollNotifier(this._service) : super(PayrollState());

  final PayrollService _service;

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final employees = await _service.fetchEmployees();
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load employees: ${error.toString()}',
      );
    }
  }

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final transactions = await _service.fetchTransactions();
      state = state.copyWith(transactions: transactions, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load transactions: ${error.toString()}',
      );
    }
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
    state = state.copyWith(isSubmitting: true, error: null, message: null);
    try {
      final success = await _service.processSalary(
        employeeId,
        periodStart,
        periodEnd,
        bankName,
        accountHolderName,
        accountNumber,
        routingNumber,
        currency: currency,
        description: description,
      );
      state = state.copyWith(
        isSubmitting: false,
        message: success ? 'Salary payment request sent successfully' : 'Salary payment request failed',
      );
      return success;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Salary payout failed: ${error.toString()}',
      );
      return false;
    }
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
    state = state.copyWith(isSubmitting: true, error: null, message: null);
    try {
      final results = await _service.bulkPay(
        employeeIds,
        periodStart,
        periodEnd,
        bankName,
        accountHolderName,
        accountNumber,
        routingNumber,
        currency: currency,
        description: description,
      );
      state = state.copyWith(
        isSubmitting: false,
        message: 'Bulk payout processed for ${results.length} employees',
      );
      return results;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Bulk payout failed: ${error.toString()}',
      );
      return [];
    }
  }
}
