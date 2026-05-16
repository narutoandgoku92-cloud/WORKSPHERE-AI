// lib/screens/payroll_employee_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payroll_provider.dart';
import '../models/payroll_model.dart';

class PayrollEmployeeListScreen extends ConsumerStatefulWidget {
  const PayrollEmployeeListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PayrollEmployeeListScreen> createState() => _PayrollEmployeeListScreenState();
}

class _PayrollEmployeeListScreenState extends ConsumerState<PayrollEmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(payrollProvider.notifier).loadEmployees());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Salary List'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : state.employees.isEmpty
                  ? const Center(child: Text('No employees available.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final employee = state.employees[index];
                        return _EmployeeCard(
                          employee: employee,
                          onPayNow: () async {
                            final completed = await showDialog<bool>(
                              context: context,
                              builder: (context) => PaySalaryDialog(employee: employee),
                            );
                            if (completed == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Salary payout requested successfully.')),
                              );
                            }
                          },
                        );
                      },
                    ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final PayrollEmployee employee;
  final VoidCallback onPayNow;

  const _EmployeeCard({
    required this.employee,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(employee.jobTitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary / hour: \$${employee.salaryPerHour.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Text('Daily rate: \$${employee.dailyRate.toStringAsFixed(2)}'),
                  ],
                ),
                ElevatedButton(
                  onPressed: onPayNow,
                  child: const Text('Pay Salary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PaySalaryDialog extends ConsumerStatefulWidget {
  final PayrollEmployee employee;

  const PaySalaryDialog({Key? key, required this.employee}) : super(key: key);

  @override
  ConsumerState<PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends ConsumerState<PaySalaryDialog> {
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 14));
  DateTime _periodEnd = DateTime.now();

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
          if (_periodStart.isAfter(_periodEnd)) {
            _periodEnd = _periodStart.add(const Duration(days: 1));
          }
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(payrollProvider.notifier);
    final state = ref.watch(payrollProvider);

    return AlertDialog(
      title: Text('Pay ${widget.employee.fullName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payroll period:'),
            const SizedBox(height: 8),
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
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: state.isSubmitting
              ? null
              : () async {
                  if (_bankNameController.text.isEmpty ||
                      _accountHolderController.text.isEmpty ||
                      _accountNumberController.text.isEmpty ||
                      _routingNumberController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all bank details.')),
                    );
                    return;
                  }
                  final success = await notifier.processSalary(
                    widget.employee.employeeId,
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
                  if (success) {
                    Navigator.of(context).pop(true);
                  }
                },
          child: state.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
