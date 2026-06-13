import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'budget_category_model.dart';
import 'transaction_provider.dart';

enum AppMode { budget, spending }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  AppMode _selectedMode = AppMode.budget;
  final _budgetController = TextEditingController(text: '50000');
  
  final Map<String, bool> _selectedCategories = {
    'Food & Groceries': true,
    'Transport & Fuel': true,
    'Leisure & Dining': true,
    'Subscriptions': true,
    'Rent & Housing': true,
    'Utilities & Bills': true,
    'Healthcare': true,
    'Shopping': true,
    'Education': true,
    'UPI': true,
    'Misc': true,
  };

  final Map<String, TextEditingController> _categoryLimitControllers = {};

  @override
  void initState() {
    super.initState();
    for (var cat in _selectedCategories.keys) {
      _categoryLimitControllers[cat] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _budgetController.dispose();
    for (var controller in _categoryLimitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalSteps => _selectedMode == AppMode.budget ? 4 : 3;

  void _nextPage() async {
    if (_currentPage < _totalSteps - 1) {
      if (_currentPage == 2 && _selectedMode == AppMode.budget) {
        // Prepare initial limits based on total budget
        final selectedCount = _selectedCategories.values.where((v) => v).length;
        if (selectedCount > 0) {
          final totalBudget = double.tryParse(_budgetController.text) ?? 50000.0;
          final perCategoryLimit = (totalBudget / selectedCount).toStringAsFixed(0);
          for (var entry in _selectedCategories.entries) {
            if (entry.value) {
              _categoryLimitControllers[entry.key]?.text = perCategoryLimit;
            }
          }
        }
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() => _currentPage++); // Move to a "processing" state visually if needed
      await _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final settingsBox = Hive.box('app_settings');
      debugPrint('Completing onboarding... Selected mode: $_selectedMode');
      await settingsBox.put('app_mode', _selectedMode.index);
      
      final notifier = ref.read(transactionProvider.notifier);
      
      // Clear and prepare categories
      final categoryBox = await Hive.openBox<BudgetCategory>('categories_box');
      await categoryBox.clear();

      if (_selectedMode == AppMode.budget) {
        for (var entry in _selectedCategories.entries) {
          if (entry.value) {
            final limit = double.tryParse(_categoryLimitControllers[entry.key]?.text ?? '0') ?? 0.0;
            notifier.addOrUpdateCategory(entry.key, limit);
          }
        }
      } else {
        // Spending mode: limits are 0
        for (var entry in _selectedCategories.entries) {
          if (entry.value) {
            notifier.addOrUpdateCategory(entry.key, 0.0);
          }
        }
      }

      debugPrint('Setting is_onboarded to true');
      await settingsBox.put('is_onboarded', true);
      await settingsBox.flush();
      
      // Small artificial delay to ensure the ValueListenableBuilder in main.dart
      // has enough time to register the state change before any other microtasks.
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Error during onboarding completion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildModeStep(theme),
                  _buildBudgetStep(theme),
                  _buildCategoriesStep(theme),
                  if (_selectedMode == AppMode.budget) _buildCategoryLimitsStep(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('BACK'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentPage == _totalSteps - 1 ? 'GET STARTED' : 'NEXT'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const Text(
            'Choose your tracking style',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'How would you like to manage your finances?',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _ModeCard(
            title: 'Budget Tracker',
            description: 'Set monthly limits for categories and track what remains.',
            icon: Icons.pie_chart,
            selected: _selectedMode == AppMode.budget,
            onTap: () => setState(() => _selectedMode = AppMode.budget),
            theme: theme,
          ),
          const SizedBox(height: 16),
          _ModeCard(
            title: 'Spending Tracker',
            description: 'Detailed log of every transaction, similar to a bank statement.',
            icon: Icons.list_alt,
            selected: _selectedMode == AppMode.spending,
            onTap: () => setState(() => _selectedMode = AppMode.spending),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStep(ThemeData theme) {
    if (_selectedMode == AppMode.spending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Spending Tracker Mode',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'In this mode, we focus on logging every detail without strict monthly limits. You can still see summaries of your spendings.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const Text(
            'Monthly Budget',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'What is your target total budget for a month?',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              prefixText: '₹ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Categories',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which categories you want to track.',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: _selectedCategories.keys.map((cat) {
                return CheckboxListTile(
                  title: Text(cat),
                  value: _selectedCategories[cat],
                  onChanged: (val) {
                    setState(() => _selectedCategories[cat] = val ?? false);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLimitsStep(ThemeData theme) {
    final selectedCats = _selectedCategories.entries.where((e) => e.value).map((e) => e.key).toList();
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Limits',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set monthly limits for each selected category.',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: selectedCats.length,
              itemBuilder: (context, index) {
                final cat = selectedCats[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _categoryLimitControllers[cat],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected 
              ? theme.colorScheme.primaryContainer 
              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: selected ? theme.colorScheme.primary : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: selected ? theme.colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected 
                          ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}