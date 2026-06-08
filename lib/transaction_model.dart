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
  final bool isExpense;

  @HiveField(6)
  final String account; // 🔥 NEW: 'Cash', 'Bank', or 'Credit'

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isExpense,
    required this.account,
  });
}