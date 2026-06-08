import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';
import 'add_transaction_modal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  await Hive.openBox<Transaction>('filous_transactions');

  runApp(
    const ProviderScope(
      child: FilousApp(),
    ),
  );
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
    final balance = ref.read(transactionProvider.notifier).totalBalance;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('FILOUS', style: TextStyle(fontWeight: FontWeight.black, letterSpacing: 1.5, fontSize: 20)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Balance Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL BALANCE', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    '₹ ${balance.toStringAsFixed(2)}', 
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 38, fontWeight: FontWeight.black)
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('RECENT TRANSACTIONS', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            
            // Transaction List
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('No transactions logged yet.\nTap below to register an entry.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, height: 1.5)))
                  : ListView.builder(
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
                          onDismissed: (direction) {
                            ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${tx.category} • ${tx.date.day}/${tx.date.month}'),
                            trailing: Text(
                              '${tx.isExpense ? "-" : "+"} ₹${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.black,
                                color: tx.isExpense ? Colors.redAccent : Colors.greenAccent,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            )
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