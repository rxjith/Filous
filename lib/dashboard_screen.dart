import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'manage_categories_modal.dart'; 
import 'add_transaction_modal.dart';   
import 'transaction_detail_modal.dart'; // 🔥 Pull in the detail/edit controller panel
import 'transaction_provider.dart';   
import 'transaction_model.dart';
import 'spending_chart.dart'; 

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Helper utility to turn transaction date values into smart relative/monthly Section Headers
  String _getGroupHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return 'TODAY';
    } else if (txDate == yesterday) {
      return 'YESTERDAY';
    } else if (now.difference(txDate).inDays < 7) {
      return DateFormat('EEEE, dd MMMM').format(date).toUpperCase();
    } else {
      return DateFormat('MMMM yyyy').format(date).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);

    // Grouping pipeline logic
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var tx in transactions) {
      final header = _getGroupHeader(tx.date);
      if (groupedTransactions[header] == null) {
        groupedTransactions[header] = [];
      }
      groupedTransactions[header]!.add(tx);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FILOUS DASHBOARD', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 24),
              tooltip: 'Configure Envelopes',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => const ManageCategoriesModal(), 
              ),
            ),
          ),
        ],
      ),
      body: transactions.isEmpty
          ? const Center(
              child: Text(
                'No transactions logged yet.\nTap + to start budgeting!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, height: 1.5),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SpendingChart(transactions: transactions),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.white10),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: groupedTransactions.length,
                    itemBuilder: (context, index) {
                      final dateHeader = groupedTransactions.keys.elementAt(index);
                      final dayTransactions = groupedTransactions[dateHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                            child: Text(
                              dateHeader,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary.withOpacity(0.8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...dayTransactions.map((tx) {
                            final isExpense = tx.isExpense;
                            final amountColor = tx.isTransfer 
                                ? Colors.blueAccent 
                                : (isExpense ? Colors.redAccent : Colors.greenAccent);
                            final leadingSign = tx.isTransfer ? '' : (isExpense ? '-' : '+');

                            // 🔥 SWIPE TO DELETE: Wraps each card inside a dismissible framework lane
                            return Dismissible(
                              key: Key(tx.id),
                              direction: DismissDirection.endToStart, // Swipe left to clear
                              background: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                              ),
                              onDismissed: (direction) {
                                // Deletes item quietly directly out of local database storage box
                                ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Removed "${tx.title}"'),
                                    backgroundColor: const Color(0xFF16162A),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: const Color(0xFF16162A), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  // 🔥 TAP TO EDIT: Launches management sheet directly targeting this model instance
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: theme.colorScheme.surface,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    builder: (context) => TransactionDetailModal(transaction: tx),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                    child: Icon(
                                      tx.isTransfer 
                                          ? Icons.swap_horiz 
                                          : (isExpense ? Icons.call_made : Icons.call_received),
                                      color: amountColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    tx.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${tx.category.toUpperCase()} • ${tx.account} • ${DateFormat('dd MMM').format(tx.date)}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ),
                                  trailing: Text(
                                    '$leadingSign${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: amountColor,
                                    ),
                                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const AddTransactionModal(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}