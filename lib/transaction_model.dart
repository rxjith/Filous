import 'package:hive/hive.dart';

// tells Hive to look for an auto generated binary adapter file
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
  final String category; // e.g., 'Food', 'Transport', 'Rent'

  @HiveField(5)
  final bool isExpense; // true for expenses, false for income

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isExpense,
  });
}