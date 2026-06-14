import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:another_telephony/telephony.dart';
import 'transaction_model.dart';
import 'budget_category_model.dart';
import 'currency_service.dart';
import 'sms_transaction_parser.dart';
import 'category_engine.dart';

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  TransactionNotifier() : super([]) {
    _initHiveAndRates();
  }

  late Box<Transaction> _transactionBox;
  Box<BudgetCategory>? _categoryBox; // Nullable to safely check initialization status
  final CurrencyService _currencyService = CurrencyService();
  
  Map<String, double> activeRates = CurrencyService.fallbackRates;

  /// Dynamically exposed categories Map derived straight from Hive storage
  Map<String, double> get categoryBudgets {
    final Map<String, double> budgets = {};
    
    // Safety Check: If Hive is still waking up, return empty instead of crashing
    if (_categoryBox == null || !_categoryBox!.isOpen) {
      return budgets;
    }

    final categories = _categoryBox!.values.toList();
    for (var cat in categories) {
      budgets[cat.name] = cat.monthlyLimit;
    }
    return budgets;
  }

  Future<void> _initHiveAndRates() async {
    _transactionBox = await Hive.openBox<Transaction>('transactions_box');
    _categoryBox = await Hive.openBox<BudgetCategory>('categories_box');
    
    // Seed standard baseline categories if the database box is completely fresh
    if (_categoryBox!.isEmpty) {
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
        'UPI': 5000.0,
        'Misc': 2000.0,
      };
      for (var entry in defaultLibrary.entries) {
        await _categoryBox!.put(entry.key, BudgetCategory(name: entry.key, monthlyLimit: entry.value));
      }
    }

    // Fetch and load active cross-currency rates
    activeRates = await _currencyService.fetchLiveRates();
    _loadAndProcess();
  }

  void _loadAndProcess() {
    final rawList = _transactionBox.values.toList();
    // Sort transactions descending by timeline execution
    rawList.sort((a, b) => b.date.compareTo(a.date));
    state = rawList; // Re-allocating the list triggers Riverpod listeners to rebuild UI
  }

  // --- Category Guessing Engine ---
  
  /// Scans a transaction name/merchant string and matches it to your seeded categories.
  String guessCategory(String title) {
    return CategoryEngine.guessCategory(title);
  }

  // --- Category Customization Controls ---
  
  void addOrUpdateCategory(String name, double limit) {
    if (_categoryBox == null || !_categoryBox!.isOpen) return;
    _categoryBox!.put(name, BudgetCategory(name: name, monthlyLimit: limit));
    _loadAndProcess(); // Instantly triggers UI re-evaluation for listeners
  }

  /// Removes a custom category and executes a cascading fallback strategy 
  /// on existing transactions to protect data integrity.
  void deleteCategory(String name) {
    if (_categoryBox == null || !_categoryBox!.isOpen) return;
    
    // Delete the category configuration asset row
    _categoryBox!.delete(name);
    
    // Cascade update records matching deleted envelopes to 'Misc'
    // This prevents runtime chart rendering failure from orphaned categories
    for (var tx in _transactionBox.values) {
      if (tx.category == name) {
        final fallbackTx = Transaction(
          id: tx.id,
          title: tx.title,
          amount: tx.amount,
          date: tx.date,
          category: 'Misc', // Re-route to safe generic stack
          account: tx.account,
          isExpense: tx.isExpense,
          isTransfer: tx.isTransfer,
          toAccount: tx.toAccount,
          recurrence: tx.recurrence,
          currency: tx.currency,
          exchangeRate: tx.exchangeRate,
        );
        _transactionBox.put(tx.id, fallbackTx);
      }
    }
    _loadAndProcess();
  }

  // --- Core Transaction Management ---

  void saveTransaction(Transaction tx) {
    // Determine optimized categorization group
    String finalCategory = tx.category.trim().isEmpty || tx.category == 'Misc'
        ? guessCategory(tx.title)
        : tx.category;

    // Inject live matching exchange rate configuration values
    // Previously, activeRates fetched from CurrencyService were never bound to transactions on save.
    double matchingRate = activeRates[tx.currency] ?? 1.0;

    final finalTx = Transaction(
      id: tx.id,
      title: tx.title,
      amount: tx.amount,
      date: tx.date,
      category: finalCategory,
      account: tx.account,
      isExpense: tx.isExpense,
      isTransfer: tx.isTransfer,
      toAccount: tx.toAccount,
      recurrence: tx.recurrence,
      currency: tx.currency,
      exchangeRate: matchingRate, // Bound dynamically to maintain reliable baseAmount conversions
    );

    _transactionBox.put(finalTx.id, finalTx);
    _loadAndProcess();
  }

  void ingestIncomingSms(SmsMessage message) {
    final parsedTransaction = SmsTransactionParser.parseIncomingMessage(message);
    if (parsedTransaction == null) return;
    saveTransaction(parsedTransaction);
  }

  void reloadFromStorage() {
    _loadAndProcess();
  }

  void deleteTransaction(String id) {
    _transactionBox.delete(id);
    _loadAndProcess();
  }

  void deleteTransactions(List<String> ids) {
    for (var id in ids) {
      _transactionBox.delete(id);
    }
    _loadAndProcess();
  }
}
