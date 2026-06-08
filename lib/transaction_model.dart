import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String account;

  @HiveField(5)
  final bool isExpense;

  @HiveField(6)
  final DateTime date;

  // 🔄 New: Supports internal account movements
  @HiveField(7)
  final bool isTransfer;

  @HiveField(8)
  final String? toAccount; // Required only if isTransfer is true

  // 🔁 New: Recurrence schedule tracking
  @HiveField(9)
  final String recurrence; // 'None', 'Daily', 'Weekly', 'Monthly', 'Yearly'

  // 💱 New: Multi-currency support
  @HiveField(10)
  final String currency; // e.g., 'INR', 'USD', 'EUR'

  @HiveField(11)
  final double exchangeRate; // Value relative to base currency

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.account,
    required this.isExpense,
    required this.date,
    this.isTransfer = false,
    this.toAccount,
    this.recurrence = 'None',
    this.currency = 'INR',
    this.exchangeRate = 1.0,
  });
}