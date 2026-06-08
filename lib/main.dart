import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';
import 'transaction_detail_modal.dart';
import 'add_transaction_modal.dart';

// Universal utility helper to display currency symbols correctly
String getCurrencySymbol(String currencyCode) {
  switch (currencyCode) {
    case 'USD': return '\$';
    case 'EUR': return '€';
    case 'GBP': return '£';
    default: return '₹';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('test_db');
  Hive.registerAdapter(TransactionAdapter());
  runApp(const ProviderScope(child: FilousApp()));
}

class FilousApp extends StatelessWidget {
  const FilousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Filous Budgeting',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showAddPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const AddTransactionModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final notifier = ref.read(transactionProvider.notifier);
    final theme = Theme.of(context);

    // Compute localized aggregates for current month's performance
    double totalIncome = 0;
    final Map<String, double> structuralSpending = {};

    for (var cat in notifier.categoryBudgets.keys) {
      structuralSpending[cat] = 0.0;
    }

    for (var tx in transactions) {
      if (tx.isTransfer) continue; // Transfers are value-neutral movements
      if (tx.isExpense) {
        structuralSpending[tx.category] = (structuralSpending[tx.category] ?? 0) + tx.baseAmount;
      } else {
        totalIncome += tx.baseAmount;
      }
    }

    double totalExpenses = structuralSpending.values.fold(0, (sum, item) => sum + item);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FILOUS DASHBOARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash Flow Metrics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('INFLOW (BASE)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        Text('₹${totalIncome.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('OUTFLOW (BASE)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        Text('₹${totalExpenses.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text('ACTIVE CATEGORY ENVELOPES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),

            // Dynamic Category Budgets List
            ...notifier.categoryBudgets.entries.map((entry) {
              final category = entry.key;
              final limit = entry.value;
              final spent = structuralSpending[category] ?? 0.0;
              final ratio = (spent / limit).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: ratio, color: ratio > 0.9 ? Colors.redAccent : theme.colorScheme.primary),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            const Text('TRANSACTION LEDGER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),

            // Transaction History View
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('No logged entries available.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (ctx, idx) {
                        final tx = transactions[idx];
                        final displaySymbol = getCurrencySymbol(tx.currency);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: tx.isTransfer ? Colors.blue.withOpacity(0.2) : (tx.isExpense ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
                            child: Icon(
                              tx.isTransfer ? Icons.swap_horiz : (tx.isExpense ? Icons.arrow_downward : Icons.arrow_upward),
                              color: tx.isTransfer ? Colors.blueAccent : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                            ),
                          ),
                          title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(tx.isTransfer ? '${tx.account} ➔ ${tx.toAccount}' : '${tx.account} • ${tx.category}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${tx.isExpense ? "-" : "+"} $displaySymbol${tx.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: tx.isTransfer ? Colors.blue.withOpacity(0.8) : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white38),
                                onPressed: () => notifier.deleteTransaction(tx.id),
                              ),
                            ],
                          ),
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => TransactionDetailModal(transaction: tx),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPanel(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        label: const Text('Log Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }
}