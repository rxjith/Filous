import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; 
import 'transaction_model.dart';
import 'transaction_provider.dart';
import 'transaction_detail_modal.dart';
import 'add_transaction_modal.dart';

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

    double totalIncome = 0;
    final Map<String, double> structuralSpending = {};

    for (var cat in notifier.categoryBudgets.keys) {
      structuralSpending[cat] = 0.0;
    }

    for (var tx in transactions) {
      if (tx.isTransfer) continue;
      if (tx.isExpense) {
        structuralSpending[tx.category] = (structuralSpending[tx.category] ?? 0) + tx.baseAmount;
      } else {
        totalIncome += tx.baseAmount;
      }
    }

    double totalExpenses = structuralSpending.values.fold(0, (sum, item) => sum + item);

    // Multi-tier Sorting Map Array Engine: Month Banner -> (Day Banner -> Multi-logs)
    final Map<String, Map<String, List<Transaction>>> segregatedLogs = {};

    for (var tx in transactions) {
      final monthKey = DateFormat('MMMM yyyy').format(tx.date); 
      final dayKey = DateFormat('EEE, dd MMM').format(tx.date);   

      if (!segregatedLogs.containsKey(monthKey)) {
        segregatedLogs[monthKey] = {};
      }
      if (!segregatedLogs[monthKey]!.containsKey(dayKey)) {
        segregatedLogs[monthKey]![dayKey] = [];
      }
      segregatedLogs[monthKey]![dayKey]!.add(tx);
    }

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

            Expanded(
              child: segregatedLogs.isEmpty
                  ? const Center(child: Text('No logged entries available.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: segregatedLogs.keys.length,
                      itemBuilder: (ctx, monthIdx) {
                        final monthString = segregatedLogs.keys.elementAt(monthIdx);
                        final dayGroups = segregatedLogs[monthString]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  monthString.toUpperCase(),
                                  // 🔥 FIXED PERMANENTLY TO W900
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, letterSpacing: 1),
                                ),
                              ),
                            ),
                            
                            ...dayGroups.entries.map((dayEntry) {
                              final dayString = dayEntry.key;
                              final subTransactions = dayEntry.value;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: theme.colorScheme.surfaceContainerLow,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayString,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white60),
                                      ),
                                      const Divider(height: 16, color: Colors.white10),
                                      
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: subTransactions.length,
                                        itemBuilder: (context, txIdx) {
                                          final tx = subTransactions[txIdx];
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
                                            title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            subtitle: Text(tx.isTransfer ? '${tx.account} ➔ ${tx.toAccount}' : '${tx.account} • ${tx.category}', style: const TextStyle(fontSize: 12)),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${tx.isExpense ? "-" : "+"} $displaySymbol${tx.amount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                    color: tx.isTransfer ? Colors.blue.withOpacity(0.8) : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
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
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
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