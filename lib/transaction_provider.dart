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
  Box<BudgetCategory>? _categoryBox; // Nullable to safely check initialization status
  final CurrencyService _currencyService = CurrencyService();
  
  Map<String, double> activeRates = CurrencyService.fallbackRates;

  // Dynamically exposed categories Map derived straight from Hive storage
  Map<String, double> get categoryBudgets {
    final Map<String, double> budgets = {};
    
    // 🔥 Safety Check: If Hive is still waking up, return empty instead of crashing
    if (_categoryBox == null || !_categoryBox!.isOpen) {
      return budgets;
    }

    for (var cat in _categoryBox!.values) {
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
        'Misc': 2000.0,
      };
      for (var entry in defaultLibrary.entries) {
        await _categoryBox!.put(entry.key, BudgetCategory(name: entry.key, monthlyLimit: entry.value));
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

  // --- 🔥 Automated Category Guessing Engine ---
  
  /// Scans a transaction name/merchant string and matches it to your seeded categories.
  String guessCategory(String title) {
    final cleanTitle = title.toLowerCase().trim();

    // Contextual matching keywords dictionary
    final Map<String, List<String>> keywordRules = {
      'Food & Groceries': [
        'swiggy', 'zomato', 'blinkit', 'zepto', 'instamart', 'bigbasket', 
        'supermarket', 'grocery', 'kfc', 'mcdonald', 'starbucks', 'bakes', 
        'restaurant', 'cafe', 'hotel', 'dine'
      ],
      'Transport & Fuel': [
        'uber', 'ola', 'rapido', 'petrol', 'diesel', 'fuel', 'pump', 'iocl', 
        'hpcl', 'bpcl', 'irctc', 'railway', 'metro', 'auto', 'travel', 'flight'
      ],
      'Leisure & Dining': [
        'bookmyshow', 'pvr', 'cinema', 'movies', 'theatre', 'pub', 'bar', 
        'lounge', 'club', 'gaming', 'resort', 'ticket'
      ],
      'Subscriptions': [
        'netflix', 'spotify', 'youtube', 'premium', 'apple', 'icloud', 
        'prime', 'hotstar', 'sony', 'live', 'gsuite', 'github', 'openai'
      ],
      'Utilities & Bills': [
        'jio', 'airtel', 'vi ', 'bsnl', 'recharge', 'electricity', 'kseb', 
        'water', 'gas', 'broadband', 'wi-fi', 'postpaid', 'insurance_bill'
      ],
      'Healthcare': [
        'pharmacy', 'medplus', 'apollo', 'pharmeasy', 'hospital', 'clinic', 
        'medical', 'doctor', 'lab ', 'dentist'
      ],
      'Shopping': [
        'amazon', 'flipkart', 'myntra', 'ajio', 'zara', 'h&m', 'trends', 
        'lifestyle', 'clothing', 'footwear', 'mall', 'electronics'
      ],
      'Education': [
        'udemy', 'coursera', 'fees', 'college', 'tuition', 'books', 'xerox', 
        'stationery', 'academy'
      ],
      'Rent & Housing': [
        'rent', 'landlord', 'deposit', 'maintenance', 'roommate'
      ],
    };

    for (var entry in keywordRules.entries) {
      for (var keyword in entry.value) {
        if (cleanTitle.contains(keyword)) {
          return entry.key; // Found an explicit rule match!
        }
      }
    }

    return 'Misc'; // Fallback if it completely slips matching filters
  }

  // --- Category Customization Controls ---
  
  void addOrUpdateCategory(String name, double limit) {
    if (_categoryBox == null || !_categoryBox!.isOpen) return;
    _categoryBox!.put(name, BudgetCategory(name: name, monthlyLimit: limit));
    _loadAndProcess(); // Triggers UI state re-evaluation
  }

  void deleteCategory(String name) {
    if (_categoryBox == null || !_categoryBox!.isOpen) return;
    _categoryBox!.delete(name);
    _loadAndProcess();
  }

  // --- Core Transaction Management ---

  void saveTransaction(Transaction tx) {
    Transaction finalTx = tx;

    // 🔥 If the transaction is incoming with a blank category or labeled as 'Misc', 
    // try to guess a much tighter categorization group based on its transaction name.
    if (tx.category == 'Misc' || tx.category.isEmpty) {
      final guessed = guessCategory(tx.title);
      if (guessed != 'Misc') {
        finalTx = Transaction(
          id: tx.id,
          title: tx.title,
          amount: tx.amount,
          date: tx.date,
          category: guessed, // Injected suggestion slot
          account: tx.account,
          currency: tx.currency,
          isExpense: tx.isExpense,
          isTransfer: tx.isTransfer,
        );
      }
    }

    _transactionBox.put(finalTx.id, finalTx);
    _loadAndProcess();
  }

  void deleteTransaction(String id) {
    _transactionBox.delete(id);
    _loadAndProcess();
  }
}