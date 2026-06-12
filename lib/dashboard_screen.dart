import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'manage_categories_modal.dart'; 
import 'add_transaction_page.dart';   
import 'settings_page.dart';
import 'transaction_detail_modal.dart';
import 'transaction_provider.dart';
import 'spending_chart.dart';
import 'app_mode_provider.dart';
import 'onboarding_screen.dart';
import 'transaction_history_page.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final budgets = ref.watch(transactionProvider.notifier).categoryBudgets;
    final appMode = ref.watch(appModeProvider);
    final now = DateTime.now();
    
    final monthlyExpenses = transactions.where((tx) {
      return tx.isExpense &&
          tx.date.year == now.year &&
          tx.date.month == now.month;
    }).toList();

    final monthlyIncome = transactions.where((tx) {
      return !tx.isExpense &&
          !tx.isTransfer &&
          tx.date.year == now.year &&
          tx.date.month == now.month;
    }).toList();

    // Aggregate spending by category for the current month
    final Map<String, double> categorySpending = {};
    for (var tx in monthlyExpenses) {
      categorySpending[tx.category] = (categorySpending[tx.category] ?? 0.0) + tx.baseAmount;
    }

    final totalBudget = budgets.values.fold<double>(0, (sum, limit) => sum + limit);
    final totalSpent = monthlyExpenses.fold<double>(0, (sum, tx) => sum + tx.baseAmount);
    final totalIncome = monthlyIncome.fold<double>(0, (sum, tx) => sum + tx.baseAmount);
    
    // 🔥 Income Increment: receiving money increases your available budget for the month
    final effectiveTotalBudget = totalBudget + totalIncome;
    final remainingBudget = effectiveTotalBudget > totalSpent ? effectiveTotalBudget - totalSpent : 0.0;
    final budgetProgress = effectiveTotalBudget == 0 ? 0.0 : (totalSpent / effectiveTotalBudget).clamp(0.0, 1.0);

    final budgetCard = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appMode == AppMode.budget ? 'MONTHLY BUDGET' : 'MONTHLY SPENDING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              appMode == AppMode.budget
                  ? (totalBudget == 0
                      ? 'Set category budgets to track what remains'
                      : '₹${remainingBudget.toStringAsFixed(0)} left this month')
                  : '₹${totalSpent.toStringAsFixed(0)} spent out of ₹${totalIncome.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: appMode == AppMode.budget && remainingBudget == 0 && totalBudget > 0
                    ? Colors.redAccent
                    : theme.colorScheme.primary,
              ),
            ),
            if (appMode == AppMode.budget && totalBudget > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: budgetProgress,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    budgetProgress >= 1 ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              appMode == AppMode.budget
                  ? (totalBudget == 0
                      ? 'No monthly limits configured yet.'
                      : 'Spent: ₹${totalSpent.toStringAsFixed(0)} / ₹${totalBudget.toStringAsFixed(0)}')
                  : 'Tracking your transactions meticulously.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );

    final categoryBudgetSection = budgets.isEmpty 
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CATEGORY BREAKDOWN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 12),
                ...budgets.keys.map((category) {
                  final limit = budgets[category] ?? 0.0;
                  final spent = categorySpending[category] ?? 0.0;
                  final progress = limit == 0 ? (totalSpent == 0 ? 0.0 : (spent / totalSpent)) : (spent / limit).clamp(0.0, 1.0);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              appMode == AppMode.budget && limit > 0
                                  ? '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}'
                                  : '₹${spent.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: appMode == AppMode.budget && limit > 0 && spent >= limit
                                    ? Colors.redAccent
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              appMode == AppMode.budget && limit > 0 && progress >= 1 
                                  ? Colors.redAccent 
                                  : theme.colorScheme.primary.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );

    final spendingSection = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY SPENDING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 12),
          ...categorySpending.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${entry.value.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Filous', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            letterSpacing: 0.5,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 24),
              tooltip: 'Configure Envelopes',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => const ManageCategoriesModal(), 
              ),
            ),
          ),
        ],
      ),
      body: transactions.isEmpty && budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'No transactions logged yet!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button below to log an entry.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: budgetCard),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (appMode == AppMode.budget) 
                  SliverToBoxAdapter(child: categoryBudgetSection)
                else ...[
                  SliverToBoxAdapter(child: SpendingChart(transactions: transactions)),
                  SliverToBoxAdapter(child: spendingSection),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 45,
            height: 45,
            child: FloatingActionButton(
              heroTag: 'history_btn',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransactionHistoryPage()),
                );
              },
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.history, size: 20, color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_btn',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTransactionPage()),
              );
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
