import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';
import 'budget_category_model.dart';
import 'currency_service.dart';

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  TransactionNotifier() : super([]) {
    _initHiveAndRates();
  }

  late Box<Transaction> _transactionBox;
  late Box<BudgetCategory> _categoryBox;
  final CurrencyService _currencyService = CurrencyService();
  
  Map<String, double> activeRates = CurrencyService.fallbackRates;

  // Dynamically exposed categories Map derived straight from Hive storage
  Map<String, double> get categoryBudgets {
    final Map<String, double> budgets = {};
    for (var cat in _categoryBox.values) {
      budgets[cat.name] = cat.monthlyLimit;
    }
    return budgets;
  }

  Future<void> _initHiveAndRates() async {
    _transactionBox = await Hive.openBox<Transaction>('transactions_box');
    _categoryBox = await Hive.openBox<BudgetCategory>('categories_box');
    
    // Seed standard baseline categories if the database box is completely fresh
    if (_categoryBox.isEmpty) {
      final defaultLibrary = {
        'Food & Groceries': 8000.0,
        'Transport & Fuel': 3000.0,
        'Leisure & Dining': 5000.0,
        'Subscriptions': 4000.0,
        'Rent & Housing': 15000.0,
        'Utilities & Bills': 5000.0,
        'Healthcare': 2000.0,
        'Shopping': 6000.0,
        'Education': 3000.0,
        'Misc': 2000.0,
      };
      for (var entry in defaultLibrary.entries) {
        await _categoryBox.put(entry.key, BudgetCategory(name: entry.key, monthlyLimit: entry.value));
      }
    }

    activeRates = await _currencyService.fetchLiveRates();
    _loadAndProcess();
  }

  void _loadAndProcess() {
    final rawList = _transactionBox.values.toList();
    rawList.sort((a, b) => b.date.compareTo(a.date));
    state = rawList;
  }

  // --- Category Customization Controls ---
  
  void addOrUpdateCategory(String name, double limit) {
    _categoryBox.put(name, BudgetCategory(name: name, monthlyLimit: limit));
    _loadAndProcess(); // Triggers UI state re-evaluation
  }

  void deleteCategory(String name) {
    _categoryBox.delete(name);
    _loadAndProcess();
  }

  // --- Core Transaction Management ---

  void saveTransaction(Transaction tx) {
    _transactionBox.put(tx.id, tx);
    _loadAndProcess();
  }

  void deleteTransaction(String id) {
    _transactionBox.delete(id);
    _loadAndProcess();
  }
}