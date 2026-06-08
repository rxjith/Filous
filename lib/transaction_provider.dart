import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';
import 'currency_service.dart';

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  TransactionNotifier() : super([]) {
    _initHiveAndRates();
  }

  late Box<Transaction> _box;
  final CurrencyService _currencyService = CurrencyService();
  
  // Publicly exposed runtime translation metrics
  Map<String, double> activeRates = CurrencyService.fallbackRates;

  final Map<String, double> categoryBudgets = {
    'Food': 8000.0,
    'Transport': 3000.0,
    'Leisure': 5000.0,
    'Subscriptions': 4000.0,
    'Misc': 2000.0,
  };

  Future<void> _initHiveAndRates() async {
    _box = await Hive.openBox<Transaction>('transactions_box');
    activeRates = await _currencyService.fetchLiveRates();
    _loadAndProcess();
  }

  void _loadAndProcess() {
    final rawList = _box.values.toList();
    // Sort chronologically descending (newest entries first)
    rawList.sort((a, b) => b.date.compareTo(a.date));
    state = rawList;
    _processRecurringSchedules(rawList);
  }

  void saveTransaction(Transaction tx) {
    _box.put(tx.id, tx);
    _loadAndProcess();
  }

  void deleteTransaction(String id) {
    _box.delete(id);
    _loadAndProcess();
  }

  void _processRecurringSchedules(List<Transaction> currentTxs) {
    final now = DateTime.now();
    List<Transaction> newSpawns = [];
    final processedBaseTitles = <String>{};

    for (var tx in currentTxs) {
      if (tx.recurrence == 'None' || processedBaseTitles.contains(tx.title)) continue;
      processedBaseTitles.add(tx.title);

      DateTime lastTriggerDate = tx.date;
      for (var checkTx in currentTxs) {
        if (checkTx.title == tx.title && checkTx.date.isAfter(lastTriggerDate)) {
          lastTriggerDate = checkTx.date;
        }
      }

      DateTime nextDueDate = _calculateNextDate(lastTriggerDate, tx.recurrence);

      while (nextDueDate.isBefore(now)) {
        final uniqueId = '${tx.id}_spawn_${nextDueDate.year}_${nextDueDate.month}_${nextDueDate.day}';
        
        if (!_box.containsKey(uniqueId)) {
          newSpawns.add(Transaction(
            id: uniqueId,
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
          ));
        }
        nextDueDate = _calculateNextDate(nextDueDate, tx.recurrence);
      }
    }

    if (newSpawns.isNotEmpty) {
      for (var spawnedTx in newSpawns) {
        _box.put(spawnedTx.id, spawnedTx);
      }
      _loadAndProcess();
    }
  }

  DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'Daily': return current.add(const Duration(days: 1));
      case 'Weekly': return current.add(const Duration(days: 7));
      case 'Monthly': return DateTime(current.year, current.month + 1, current.day);
      case 'Yearly': return DateTime(current.year + 1, current.month, current.day);
      default: return current;
    }
  }
}