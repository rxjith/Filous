import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final Box<Transaction> _box = Hive.box<Transaction>('filous_transactions');

  // Hardcoded Budget thresholds matching Cashew's envelope methodology
  final Map<String, double> categoryBudgets = {
    'Food': 4000.00,
    'Transport': 1500.00,
    'Leisure': 3000.00,
    'Subscriptions': 2000.00,
    'Misc': 5000.00,
  };

  TransactionNotifier() : super([]) {
    _loadTransactions();
  }

  void updateTransaction(Transaction updatedTransaction) {
    _box.put(updatedTransaction.id, updatedTransaction);
    _loadTransactions(); // Refresh the live state feed
  }

  void _loadTransactions() {
    state = _box.values.toList().reversed.toList();
  }

  void addTransaction(Transaction transaction) {
    _box.put(transaction.id, transaction);
    _loadTransactions();
  }

  void deleteTransaction(String id) {
    _box.delete(id);
    _loadTransactions();
  }

  // Live aggregated balances for segregated accounts
  double getAccountBalance(String accountName) {
    double total = 0.0;
    for (var tx in state) {
      if (tx.account == accountName) {
        total += tx.isExpense ? -tx.amount : tx.amount;
      }
    }
    return total;
  }

  double get totalBalance {
    double balance = 0.0;
    for (var tx in state) {
      balance += tx.isExpense ? -tx.amount : tx.amount;
    }
    return balance;
  }

  // Tracks exact current usage for a single specific category envelope
  double getCategorySpending(String category) {
    return state
        .where((tx) => tx.category == category && tx.isExpense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }
}