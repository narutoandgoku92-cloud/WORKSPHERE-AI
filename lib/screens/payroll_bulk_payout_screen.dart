// lib/screens/payroll_bulk_payout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payroll_provider.dart';
import '../models/payroll_model.dart';

class PayrollBulkPayoutScreen extends ConsumerStatefulWidget {
  const PayrollBulkPayoutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PayrollBulkPayoutScreen> createState() => _PayrollBulkPayoutScreenState();
}

class _PayrollBulkPayoutScreenState extends ConsumerState<PayrollBulkPayoutScreen> {
  final Map<String, bool> _selected = {};
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 14));
  DateTime _periodEnd = DateTime.now();
  List<PayrollPayoutResult> _results = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(payrollProvider.notifier).loadEmployees());
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _routingNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _periodStart : _periodEnd;
    final firstDate = DateTime.now().subtract(const Duration(days: 365));
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
          if (_periodEnd.isBefore(_periodStart)) {
            _periodEnd = _periodStart.add(const Duration(days: 1));
          }
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  Future<void> _submitBulkPayout() async {
    final selectedEmployeeIds = _selected.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee.')),
      );
      return;
    }

    if (_bankNameController.text.isEmpty ||
        _accountHolderController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _routingNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide bank details for bulk payout.')),
      );
      return;
    }

    final results = await ref.read(payrollProvider.notifier).bulkPay(
          selectedEmployeeIds,
          _periodStart,
          _periodEnd,
          _bankNameController.text.trim(),
          _accountHolderController.text.trim(),
          _accountNumberController.text.trim(),
          _routingNumberController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );

    setState(() {
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Salary Payout'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Select employees to include in a single bulk payout transaction.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ...state.employees.map((employee) {
                        _selected.putIfAbsent(employee.employeeId, () => false);
                        return CheckboxListTile(
                          value: _selected[employee.employeeId],
                          onChanged: (value) {
                            setState(() {
                              _selected[employee.employeeId] = value ?? false;
                            });
                          },
                          title: Text(employee.fullName),
                          subtitle: Text('Hourly: \$${employee.salaryPerHour.toStringAsFixed(2)}'),
                        );
                      }),
                      const SizedBox(height: 20),
                      Text('Shared bank details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(labelText: 'Bank name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _accountHolderController,
                        decoration: const InputDecoration(labelText: 'Account holder'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _accountNumberController,
                        decoration: const InputDecoration(labelText: 'Account number'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _routingNumberController,
                        decoration: const InputDecoration(labelText: 'Routing number'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _selectDate(context, true),
                              child: Text('Start: ${_periodStart.toLocal().toString().split(' ').first}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _selectDate(context, false),
                              child: Text('End: ${_periodEnd.toLocal().toString().split(' ').first}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submitBulkPayout,
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit Bulk Payout'),
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Bulk payout results', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ..._results.map((result) => Card(
                              child: ListTile(
                                title: Text(result.employeeId),
                                subtitle: Text(result.message),
                                trailing: Text(result.status.toUpperCase()),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
