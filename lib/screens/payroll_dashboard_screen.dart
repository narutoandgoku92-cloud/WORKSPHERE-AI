// lib/screens/payroll_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/payroll_provider.dart';

class PayrollDashboardScreen extends ConsumerWidget {
  const PayrollDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollState = ref.watch(payrollProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(payrollProvider.notifier).loadEmployees();
          await ref.read(payrollProvider.notifier).loadTransactions();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payroll Center',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (payrollState.error != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(payrollState.error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SummaryCard(
                    title: 'Employees',
                    value: payrollState.employees.length.toString(),
                    icon: Icons.group,
                    color: Colors.blue,
                  ),
                  _SummaryCard(
                    title: 'Transactions',
                    value: payrollState.transactions.length.toString(),
                    icon: Icons.receipt_long,
                    color: Colors.teal,
                  ),
                  _SummaryCard(
                    title: 'Loading',
                    value: payrollState.isLoading ? 'Yes' : 'No',
                    icon: Icons.sync,
                    color: Colors.orange,
                  ),
                  _SummaryCard(
                    title: 'Pending Actions',
                    value: payrollState.isSubmitting ? 'Busy' : 'Ready',
                    icon: Icons.payments,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/payroll/employees'),
                icon: const Icon(Icons.list),
                label: const Text('Employee Salary List'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/payroll/bulk'),
                icon: const Icon(Icons.send_to_mobile),
                label: const Text('Bulk Payout'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/payroll/transactions'),
                icon: const Icon(Icons.history),
                label: const Text('Transaction History'),
              ),
              const SizedBox(height: 24),
              if (payrollState.message != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(payrollState.message!, style: const TextStyle(color: Colors.green)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
