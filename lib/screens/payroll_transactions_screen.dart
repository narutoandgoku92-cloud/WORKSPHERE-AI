// lib/screens/payroll_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payroll_provider.dart';

class PayrollTransactionsScreen extends ConsumerStatefulWidget {
  const PayrollTransactionsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PayrollTransactionsScreen> createState() => _PayrollTransactionsScreenState();
}

class _PayrollTransactionsScreenState extends ConsumerState<PayrollTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(payrollProvider.notifier).loadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(payrollProvider.notifier).loadTransactions(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : state.transactions.isEmpty
                  ? const Center(child: Text('No payroll transactions found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final transaction = state.transactions[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Transaction ID: ${transaction.id}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Employee: ${transaction.employeeId}'),
                                Text('Amount: \$${transaction.amount.toStringAsFixed(2)} ${transaction.currency}'),
                                Text('Status: ${transaction.status}'),
                                if (transaction.failureReason != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Failure: ${transaction.failureReason}', style: const TextStyle(color: Colors.red)),
                                ],
                                if (transaction.details != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Details: ${transaction.details}'),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
