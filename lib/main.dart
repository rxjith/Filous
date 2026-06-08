import 'dart:io'; // Required for path overriding
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_detail_modal.dart'; // Handles Read & Update operations
import 'transaction_model.dart';
import 'transaction_provider.dart';
import 'add_transaction_modal.dart';
import 'spending_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  
  // 1. Force a localized sandbox directory inside the project workspace to prevent system cache crashes
  final testDir = Directory('${Directory.current.path}/test_db');
  if (await testDir.exists()) {
    try {
      await testDir.delete(recursive: true);
    } catch (e) {
      // Catch file system locks gracefully if any
    }
  }
  Hive.init(testDir.path); 

  // 2. Open the clean box instance safely
  await Hive.openBox<Transaction>('filous_transactions');

  runApp(const ProviderScope(child: FilousApp()));
}

class FilousApp extends StatelessWidget {
  const FilousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        const fallbackDarkScheme = ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
          surface: Color(0xFF121212),
        );
        return MaterialApp(
          title: 'Filous',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? fallbackDarkScheme,
            scaffoldBackgroundColor: darkDynamic?.surface ?? Colors.black,
          ),
          home: const FilousDashboard(),
        );
      },
    );
  }
}

class FilousDashboard extends ConsumerWidget {
  const FilousDashboard({super.key});

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
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final notifier = ref.watch(transactionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FILOUS x CASHEW', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 20)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 💳 CASHEW MULTI-ACCOUNT ROW LAYOUT
              Row(
                children: ['Cash', 'Bank', 'Credit'].map((acc) {
                  final bal = notifier.getAccountBalance(acc);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('₹${bal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Visual Analytics Ring
              SpendingChart(transactions: transactions),
              const SizedBox(height: 16),

              // 📊 CASHEW LIVE BUDGET ENVELOPE PROGRESS GAUGE BAR LIST
              Text('ACTIVE BUDGETS', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              ...notifier.categoryBudgets.entries.map((budget) {
                final category = budget.key;
                final limit = budget.value;
                final spent = notifier.getCategorySpending(category);
                double percent = spent / limit;
                if (percent > 1.0) percent = 1.0; 

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(spent > limit ? Colors.redAccent : theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 28),
              Text('RECENT TRANSACTIONS', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),

              // Scrollable Ledger List
              transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No entries registered.', style: TextStyle(color: Colors.white38))),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return Dismissible(
                          key: Key(tx.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.withOpacity(0.1),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          onDismissed: (_) => notifier.deleteTransaction(tx.id),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            
                            // 🔥 R (Read) & U (Update) Hooks Linked via Tap Event
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: theme.colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) => TransactionDetailModal(transaction: tx),
                              );
                            },
                            
                            title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${tx.category} • ${tx.account}'),
                            trailing: Text(
                              '${tx.isExpense ? "-" : "+"} ₹${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                color: tx.isExpense ? Colors.redAccent : Colors.greenAccent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
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