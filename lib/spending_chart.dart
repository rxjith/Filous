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
      categoryMap[tx.category] = (categoryMap[tx.category] ?? 0.0) + tx.baseAmount;
      totalSpending += tx.baseAmount;
    }

    // Preset Color Palette
    final List<Color> dynamicPalette = [
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.lightGreenAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.blueGrey,
    ];

    // Assign colors to whatever categories exist in runtime dynamically
    final Map<String, Color> categoryColors = {};
    final activeCategories = categoryMap.keys.toList();
    for (int i = 0; i < activeCategories.length; i++) {
      categoryColors[activeCategories[i]] = dynamicPalette[i % dynamicPalette.length];
    }

    // Map aggregated values to fl_chart data structures without title text inside
    final List<PieChartSectionData> sections = categoryMap.entries.map((entry) {
      // Pulls dynamic color instead of looking for hardcoded strings
      final color = categoryColors[entry.key] ?? theme.colorScheme.primary;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '', // Keep the ring clean
        radius: 20,
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 140,
      child: Row(
        children: [
          // Pure geometric ring canvas
          Expanded(
            flex: 4,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 42,
                sections: sections,
              ),
            ),
          ),
          
          // Index with Inline Percentages
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categoryMap.entries.map((entry) {
                  final cat = entry.key;
                  final amount = entry.value;
                  final percentage = (amount / totalSpending) * 100;
                  // Match legend color exactly with chart section slice
                  final color = categoryColors[cat] ?? theme.colorScheme.primary;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 8, 
                          height: 8, 
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${cat.toUpperCase()} (${percentage.toStringAsFixed(0)}%)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: theme.colorScheme.onSurface.withOpacity(0.7), 
                              letterSpacing: 0.5,
                            ),
                          ),
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