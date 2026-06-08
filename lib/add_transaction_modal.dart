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
  bool _isTransfer = false;
  
  String _selectedCategory = 'Food';
  String _selectedAccount = 'Cash';
  String _selectedToAccount = 'Bank';
  String _selectedRecurrence = 'None';
  String _selectedCurrency = 'INR';

  final List<String> _categories = ['Food', 'Transport', 'Leisure', 'Subscriptions', 'Misc'];
  final List<String> _accounts = ['Cash', 'Bank', 'Credit'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  // Mock exchange rate table relative to standard baseline currency conversion bounds
  final Map<String, double> _rates = {'INR': 1.0, 'USD': 0.012, 'EUR': 0.011, 'GBP': 0.0095};

  void _submitData() {
    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (enteredTitle.isEmpty || enteredAmount <= 0) return;

    // Standardize inverse exchange ratios relative to base calculations
    double rate = _rates[_selectedCurrency] ?? 1.0;
    double standardizedRate = 1.0 / rate; 

    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: enteredTitle,
      amount: enteredAmount,
      date: DateTime.now(),
      category: _isTransfer ? 'Transfer' : _selectedCategory,
      account: _selectedAccount,
      isExpense: _isTransfer ? false : _isExpense,
      isTransfer: _isTransfer,
      toAccount: _isTransfer ? _selectedToAccount : null,
      recurrence: _selectedRecurrence,
      currency: _selectedCurrency,
      exchangeRate: standardizedRate,
    );

    ref.read(transactionProvider.notifier).saveTransaction(newTx);
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
            Text('LOG ENTRY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 16),
            
            // Transaction Type Selector Block
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Expense')),
                    selected: _isExpense && !_isTransfer,
                    onSelected: (val) => setState(() { _isExpense = true; _isTransfer = false; }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Income')),
                    selected: !_isExpense && !_isTransfer,
                    onSelected: (val) => setState(() { _isExpense = false; _isTransfer = false; }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Transfer')),
                    selected: _isTransfer,
                    onSelected: (val) => setState(() { _isTransfer = true; }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Description / Payee', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Currency'),
                    items: _currencies.map((cur) => DropdownMenuItem(value: cur, child: Text(cur))).toList(),
                    onChanged: (val) => setState(() => _selectedCurrency = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAccount,
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: _isTransfer ? 'From Account' : 'Account'),
                    items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
                    onChanged: (val) => setState(() => _selectedAccount = val!),
                  ),
                ),
                if (_isTransfer) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedToAccount,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'To Account'),
                      items: _accounts.where((a) => a != _selectedAccount).map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
                      onChanged: (val) => setState(() => _selectedToAccount = val!),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (!_isTransfer) ...[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category Envelope'),
                      items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRecurrence,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Recurrence Schedule'),
                    items: _recurrences.map((rec) => DropdownMenuItem(value: rec, child: Text(rec))).toList(),
                    onChanged: (val) => setState(() => _selectedRecurrence = val!),
                  ),
                ),
              ],
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
                child: const Text('Save Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}