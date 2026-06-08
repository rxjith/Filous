import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  const AddTransactionModal({super.key});

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isExpense = true;
  String _selectedCategory = 'Food';

  final List<String> _categories = ['Food', 'Transport', 'Leisure', 'Subscriptions', 'Salary', 'Misc'];

  void _submitData() {
    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (enteredTitle.isEmpty || enteredAmount <= 0) return;

    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: enteredTitle,
      amount: enteredAmount,
      date: DateTime.now(),
      category: _selectedCategory,
      isExpense: _isExpense,
    );

    ref.read(transactionProvider.notifier).addTransaction(newTx);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEW ENTRY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Expense', style: TextStyle(fontWeight: FontWeight.bold))),
                    selected: _isExpense,
                    onSelected: (val) => setState(() => _isExpense = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Income', style: TextStyle(fontWeight: FontWeight.bold))),
                    selected: !_isExpense,
                    onSelected: (val) => setState(() => _isExpense = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Description / Store', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category'),
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}