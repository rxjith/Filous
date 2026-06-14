import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'transaction_provider.dart';
import 'transaction_detail_modal.dart';

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends ConsumerState<TransactionHistoryPage> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _deleteSelected() {
    final count = _selectedIds.length;
    ref.read(transactionProvider.notifier).deleteTransactions(_selectedIds.toList());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $count transactions'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection)
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Transaction History', 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Transactions'),
                    content: Text('Are you sure you want to delete ${_selectedIds.length} transactions?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteSelected();
                        }, 
                        child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
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
                final isSelected = _selectedIds.contains(tx.id);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onLongPress: () => _toggleSelection(tx.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected 
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : Colors.transparent,
                      ),
                      child: Card(
                        elevation: 0,
                        color: isSelected 
                            ? Colors.transparent 
                            : theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(tx.id);
                            } else {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: theme.colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) => TransactionDetailModal(transaction: tx),
                              );
                            }
                          },
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
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
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                                  ),
                                ),
                            ],
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
                  ),
                );
              },
            ),
    );
  }
}
