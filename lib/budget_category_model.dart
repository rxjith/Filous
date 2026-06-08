import 'package:hive/hive.dart';

part 'budget_category_model.g.dart';

@HiveType(typeId: 1)
class BudgetCategory extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double monthlyLimit;

  BudgetCategory({
    required this.name,
    required this.monthlyLimit,
  });
}