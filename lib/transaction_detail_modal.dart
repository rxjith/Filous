import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class TransactionDetailModal extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionDetailModal({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailModal> createState() => _TransactionDetailModalState();
}

class _TransactionDetailModalState extends ConsumerState<TransactionDetailModal> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  
  late bool _isExpense;
  late bool _isTransfer;
  
  late String _selectedCategory;
  late String _selectedAccount;
  late String _selectedToAccount;
  late String _selectedRecurrence;
  late String _selectedCurrency;
  bool _isEditing = false; // Toggle state between READ and EDIT modes

  final List<String> _categories = ['Food', 'Transport', 'Leisure', 'Subscriptions', 'Misc'];
  final List<String> _accounts = ['Cash', 'Bank', 'Credit'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  // Mock conversion multipliers relative to baseline currency indices
  final Map<String, double> _rates = {'INR': 1.0, 'USD': 0.012, 'EUR': 0.011, 'GBP': 0.0095};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(0));
    _isExpense = widget.transaction.isExpense;
    _isTransfer = widget.transaction.isTransfer;
    _selectedCategory = widget.transaction.category;
    _selectedAccount = widget.transaction.account;
    _selectedToAccount = widget.transaction.toAccount ?? 'Bank';
    _selectedRecurrence = widget.transaction.recurrence;
    _selectedCurrency = widget.transaction.currency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (enteredTitle.isEmpty || enteredAmount <= 0) return;

    double rate = _rates[_selectedCurrency] ?? 1.0;
    double standardizedRate = 1.0 / rate;

    final updatedTx = Transaction(
      id: widget.transaction.id, // Retain original database record key
      title: enteredTitle,
      amount: enteredAmount,
      date: widget.transaction.date, // Retain original logging timestamp
      category: _isTransfer ? 'Transfer' : _selectedCategory,
      account: _selectedAccount,
      isExpense: _isTransfer ? false : _isExpense,
      isTransfer: _isTransfer,
      toAccount: _isTransfer ? _selectedToAccount : null,
      recurrence: _selectedRecurrence,
      currency: _selectedCurrency,
      exchangeRate: standardizedRate,
    );

    ref.read(transactionProvider.notifier).saveTransaction(updatedTx);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'EDIT TRANSACTION' : 'TRANSACTION DETAILS', 
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, color: theme.colorScheme.primary),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!_isEditing) ...[
              // 📖 UPGRADED READ MODE UI
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Description / Payee', style: TextStyle(fontSize: 12, color: Colors.white38)),
                subtitle: Text(widget.transaction.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Logged Amount', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(
                        '$_selectedCurrency ${widget.transaction.amount.toStringAsFixed(2)}', 
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: _isTransfer ? Colors.blueAccent : (_isExpense ? Colors.redAccent : Colors.greenAccent)
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Flow Configuration', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(
                        _isTransfer ? 'Account Transfer 🔄' : (_isExpense ? 'Expense 🛑' : 'Income 💰'), 
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isTransfer ? 'From Account' : 'Wallet/Account', style: const TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(widget.transaction.account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isTransfer ? 'To Account' : 'Category Envelope', style: const TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(_isTransfer ? (widget.transaction.toAccount ?? 'None') : widget.transaction.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recurrence Interval', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(widget.transaction.recurrence, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (widget.transaction.currency != 'INR')
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Normalized Cost', style: TextStyle(fontSize: 12, color: Colors.white38)),
                        subtitle: Text('₹${(widget.transaction.amount * widget.transaction.exchangeRate).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white60)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              // 📝 UPGRADED UPDATE MODE FORM
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _isExpense && !_isTransfer,
                      onSelected: (val) => setState(() { _isExpense = true; _isTransfer = false; }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: !_isExpense && !_isTransfer,
                      onSelected: (val) => setState(() { _isExpense = false; _isTransfer = false; }),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category'),
                        items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRecurrence,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Recurrence'),
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
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Update Entry Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}