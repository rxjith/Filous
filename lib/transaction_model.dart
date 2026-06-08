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
  final DateTime date;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String account;

  @HiveField(6)
  final bool isExpense;

  @HiveField(7)
  final bool isTransfer;

  @HiveField(8)
  final String? toAccount;

  @HiveField(9)
  final String recurrence;

  @HiveField(10)
  final String currency;

  @HiveField(11)
  final double exchangeRate;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.account,
    required this.isExpense,
    this.isTransfer = false,
    this.toAccount,
    this.recurrence = 'None',
    this.currency = 'INR',
    this.exchangeRate = 1.0,
  });

  // Normalizes foreign amounts into the baseline standard (INR)
  double get baseAmount => amount * exchangeRate;
}