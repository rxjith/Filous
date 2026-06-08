import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';

// The state provider that the UI listens to
final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final Box<Transaction> _box = Hive.box<Transaction>('filous_transactions');

  TransactionNotifier() : super([]) {
    _loadTransactions();
  }

  // Fetch all saved data from our local SSD box
  void _loadTransactions() {
    state = _box.values.toList().reversed.toList(); // Newest first
  }

  // Save a new transaction
  void addTransaction(Transaction transaction) {
    _box.put(transaction.id, transaction);
    _loadTransactions(); // Refresh the active state
  }

  // Delete an existing transaction
  void deleteTransaction(String id) {
    _box.delete(id);
    _loadTransactions(); // Refresh the active state
  }

  // Calculate the total live balance
  double get totalBalance {
    double balance = 0.0;
    for (var tx in state) {
      if (tx.isExpense) {
        balance -= tx.amount;
      } else {
        balance += tx.amount;
      }
    }
    return balance;
  }
}