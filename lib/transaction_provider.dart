import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';

// Global provider for the active currency configuration
final baseCurrencyProvider = StateProvider<String>((ref) => 'INR');

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final Box<Transaction> _box = Hive.box<Transaction>('filous_transactions');

  // Hardcoded Cashew-style monthly envelope thresholds
  final Map<String, double> categoryBudgets = {
    'Food': 4000.00,
    'Transport': 1500.00,
    'Leisure': 3000.00,
    'Subscriptions': 2000.00,
    'Misc': 5000.00,
  };

  TransactionNotifier() : super([]) {
    _loadAndProcessTransactions();
  }

  void _loadAndProcessTransactions() {
    final rawList = _box.values.toList();
    // Run the automated recurrence checker before loading data into memory
    _processRecurringSchedules(rawList);
    state = _box.values.toList().reversed.toList();
  }

  // CREATE / UPDATE: Handles normal entries, transfers, and edits
  void saveTransaction(Transaction transaction) {
    _box.put(transaction.id, transaction);
    _loadAndProcessTransactions();
  }

  // DELETE
  void deleteTransaction(String id) {
    _box.delete(id);
    _loadAndProcessTransactions();
  }

  // 💳 MULTI-ACCOUNT ACCOUNTING ENGINE
  double getAccountBalance(String accountName) {
    double total = 0.0;
    for (var tx in state) {
      // Normalize amount back to base currency value
      final baseAmount = tx.amount * tx.exchangeRate;

      if (tx.isTransfer) {
        if (tx.account == accountName) total -= baseAmount;   // Source account debited
        if (tx.toAccount == accountName) total += baseAmount; // Destination account credited
      } else {
        if (tx.account == accountName) {
          total += tx.isExpense ? -baseAmount : baseAmount;
        }
      }
    }
    return total;
  }

  // 📊 ENVELOPE BUDGET MONITOR
  double getCategorySpending(String category) {
    return state
        .where((tx) => tx.category == category && tx.isExpense && !tx.isTransfer)
        .fold(0.0, (sum, tx) => sum + (tx.amount * tx.exchangeRate));
  }

  // 🔁 CASHEW-STYLE AUTOMATED RECURRING ENGINE
  void _processRecurringSchedules(List<Transaction> currentTransactions) {
    final now = DateTime.now();
    List<Transaction> newSpawns = [];

    for (var tx in currentTransactions) {
      if (tx.recurrence == 'None') continue;

      // Find the latest recorded instance of this specific recurring chain
      DateTime lastTriggerDate = tx.date;
      for (var checkTx in currentTransactions) {
        if (checkTx.title == tx.title && checkTx.id != tx.id && checkTx.date.isAfter(lastTriggerDate)) {
          lastTriggerDate = checkTx.date;
        }
      }

      // Calculate next expected due date based on schedule rule
      DateTime nextDueDate = _calculateNextDate(lastTriggerDate, tx.recurrence);

      // Catch up if the app hasn't been opened in a while (spawning missing entries)
      while (nextDueDate.isBefore(now)) {
        final spawnedTx = Transaction(
          id: '${tx.id}_${nextDueDate.millisecondsSinceEpoch}',
          title: tx.title,
          amount: tx.amount,
          category: tx.category,
          account: tx.account,
          isExpense: tx.isExpense,
          date: nextDueDate,
          isTransfer: tx.isTransfer,
          toAccount: tx.toAccount,
          recurrence: tx.recurrence,
          currency: tx.currency,
          exchangeRate: tx.exchangeRate,
        );
        newSpawns.add(spawnedTx);
        nextDueDate = _calculateNextDate(nextDueDate, tx.recurrence);
      }
    }

    if (newSpawns.isNotEmpty) {
      for (var newTx in newSpawns) {
        _box.put(newTx.id, newTx);
      }
    }
  }

  DateTime _calculateNextDate(DateTime current, String rule) {
    switch (rule) {
      case 'Daily': return current.add(const Duration(days: 1));
      case 'Weekly': return current.add(const Duration(days: 7));
      case 'Monthly': return DateTime(current.year, current.month + 1, current.day);
      case 'Yearly': return DateTime(current.year + 1, current.month, current.day);
      default: return current;
    }
  }
}