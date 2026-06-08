import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction_model.dart';

class SpendingChart extends StatelessWidget {
  final List<Transaction> transactions;

  const SpendingChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter out only expenses
    final expenses = transactions.where((tx) => tx.isExpense).toList();
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Aggregate costs by category
    final Map<String, double> categoryMap = {};
    double totalSpending = 0.0;

    for (var tx in expenses) {
      categoryMap[tx.category] = (categoryMap[tx.category] ?? 0.0) + tx.amount;
      totalSpending += tx.amount;
    }

    // Define minimalist high-contrast colors for our categories
    final Map<String, Color> categoryColors = {
      'Food': Colors.amberAccent,
      'Transport': Colors.cyanAccent,
      'Leisure': Colors.purpleAccent,
      'Subscriptions': Colors.pinkAccent,
      'Misc': Colors.blueGrey,
    };

    // Map aggregated values to fl_chart data structures
    final List<PieChartSectionData> sections = categoryMap.entries.map((entry) {
      final isSelected = false; // Expanded configurations can go here later
      final color = categoryColors[entry.key] ?? theme.colorScheme.primary;
      final percentage = (entry.value / totalSpending) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 22,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 140,
      child: Row(
        children: [
          // Actual graphic ring
          Expanded(
            flex: 4,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          
          // Minimalist Legend Index labels
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categoryMap.keys.map((cat) {
                  final color = categoryColors[cat] ?? theme.colorScheme.primary;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          cat.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}