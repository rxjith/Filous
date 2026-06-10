import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  
  String? _selectedCategory;
  String _selectedAccount = 'Cash';
  String _selectedToAccount = 'Bank';
  String _selectedRecurrence = 'None';
  String _selectedCurrency = 'INR';
  
  DateTime _selectedDate = DateTime.now();

  final List<String> _accounts = ['Cash', 'Bank', 'Credit'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  void _presentDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (pickedDate == null) return;
    setState(() => _selectedDate = pickedDate);
  }

  void _submitData() {
    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final activeBudgets = ref.read(transactionProvider.notifier).categoryBudgets.keys.toList();

    if (enteredTitle.isEmpty || enteredAmount <= 0) return;

    String targetCategory = 'Misc';
    if (_isTransfer) {
      targetCategory = 'Transfer';
    } else if (_selectedCategory != null && activeBudgets.contains(_selectedCategory)) {
      targetCategory = _selectedCategory!;
    } else if (activeBudgets.isNotEmpty) {
      targetCategory = activeBudgets.first;
    }

    double rateMultiplier = ref.read(transactionProvider.notifier).activeRates[_selectedCurrency] ?? 1.0;

    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: enteredTitle,
      amount: enteredAmount,
      date: _selectedDate, 
      category: targetCategory,
      account: _selectedAccount,
      isExpense: _isTransfer ? false : _isExpense,
      isTransfer: _isTransfer,
      toAccount: _isTransfer ? _selectedToAccount : null,
      recurrence: _selectedRecurrence,
      currency: _selectedCurrency,
      exchangeRate: rateMultiplier,
    );

    ref.read(transactionProvider.notifier).saveTransaction(newTx);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final activeCategories = ref.watch(transactionProvider.notifier).categoryBudgets.keys.toList();

    if (_selectedCategory == null || !activeCategories.contains(_selectedCategory)) {
      _selectedCategory = activeCategories.isNotEmpty ? activeCategories.first : null;
    }

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
            Text('LOG NEW TRANSACTION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            
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

            InkWell(
              onTap: _presentDatePicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        const Text('Transaction Date:', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Description / Payee Name', border: OutlineInputBorder()),
              // 🔥 Live Guessing Engine for Creation flow: snaps dropdown dynamically while typing
              onChanged: (textValue) {
                if (!_isTransfer) {
                  final guessed = ref.read(transactionProvider.notifier).guessCategory(textValue);
                  if (guessed != 'Misc' && activeCategories.contains(guessed)) {
                    setState(() => _selectedCategory = guessed);
                  }
                }
              },
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
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: _isTransfer ? 'Source Account' : 'Wallet Account'),
                    items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAccount = val!;
                        if (_selectedAccount == _selectedToAccount) {
                          _selectedToAccount = _accounts.firstWhere((a) => a != _selectedAccount);
                        }
                      });
                    },
                  ),
                ),
                if (_isTransfer) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedToAccount,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Destination Account'),
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
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Envelope Category'),
                      items: activeCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRecurrence,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Recurrence Rule'),
                    items: _recurrences.map((rec) => DropdownMenuItem(value: rec, child: Text(rec))).toList(),
                    onChanged: (val) => setState(() => _selectedRecurrence = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Commit Entry Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}