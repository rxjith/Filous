import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'manage_categories_modal.dart'; 
import 'add_transaction_modal.dart';   
import 'transaction_detail_modal.dart';
import 'transaction_provider.dart';
import 'spending_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Watch the live stream of transactions from your StateNotifier provider
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        // 🔄 Change 1: Updated branding name to 'Filous' with crisp styling
        title: const Text(
          'Filous', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            letterSpacing: 0.5,
            fontSize: 22,
          ),
        ),
        // 🔄 Change 2: Explicitly forced left-alignment across platforms
        centerTitle: false,
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'No transactions logged yet!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button below to log an entry.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📊 1. Render the dynamic high-contrast pie chart panel up at the top
                SpendingChart(transactions: transactions),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    'RECENT TRANSACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                
                // 📜 2. Scrollable stream displaying historical entries
                Expanded(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      
                      // 🛑 3. Swipe-To-Delete gesture wrapped natively onto the cards
                      return Dismissible(
                        key: Key(tx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
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
                              content: Text('Removed execution entry for "${tx.title}"'),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 0,
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            // 🔍 4. Tap an item card to inspect/modify structural entries
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${tx.category} • ${DateFormat('dd MMM yyyy').format(tx.date)}',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${tx.isExpense ? "-" : (tx.isTransfer ? "" : "+")} ${tx.currency} ${tx.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: tx.isTransfer 
                                        ? Colors.amberAccent 
                                        : (tx.isExpense ? Colors.redAccent : Colors.greenAccent),
                                  ),
                                ),
                                // Base currency evaluation readout if dealing with foreign metrics
                                if (tx.currency != 'INR')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '₹${tx.baseAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10, 
                                        color: Colors.orangeAccent.withOpacity(0.8), 
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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