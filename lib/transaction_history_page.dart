import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'transaction_provider.dart';
import 'transaction_detail_modal.dart';

class TransactionHistoryPage extends ConsumerWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: theme.colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'No transactions yet!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Dismissible(
                    key: Key(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    ),
                    onDismissed: (direction) {
                      ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed transaction "${tx.title}"'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
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
                          backgroundColor: tx.isTransfer 
                              ? Colors.amberAccent.withOpacity(0.1) 
                              : (tx.isExpense ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1)),
                          child: Icon(
                            tx.isTransfer 
                                ? Icons.swap_horiz
                                : (tx.isExpense ? Icons.north_east : Icons.south_west),
                            color: tx.isTransfer 
                                ? Colors.amberAccent 
                                : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${tx.category} • ${DateFormat('dd MMM yyyy').format(tx.date)}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                        trailing: Text(
                          '${tx.isExpense ? "-" : (tx.isTransfer ? "" : "+")} ${tx.currency} ${tx.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: tx.isTransfer 
                                ? Colors.amberAccent 
                                : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
