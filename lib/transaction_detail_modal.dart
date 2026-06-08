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
  bool _isEditing = false; 

  final List<String> _categories = ['Food', 'Transport', 'Leisure', 'Subscriptions', 'Misc'];
  final List<String> _accounts = ['Cash', 'Bank', 'Credit'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

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

    // 🔥 Pulling directly from the live network rates table managed by the provider
    double rateMultiplier = ref.read(transactionProvider.notifier).activeRates[_selectedCurrency] ?? 1.0;

    final updatedTx = Transaction(
      id: widget.transaction.id, 
      title: enteredTitle,
      amount: enteredAmount,
      date: widget.transaction.date, 
      category: _isTransfer ? 'Transfer' : _selectedCategory,
      account: _selectedAccount,
      isExpense: _isTransfer ? false : _isExpense,
      isTransfer: _isTransfer,
      toAccount: _isTransfer ? _selectedToAccount : null,
      recurrence: _selectedRecurrence,
      currency: _selectedCurrency,
      exchangeRate: rateMultiplier,
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
                  _isEditing ? 'MODIFY ENTRIES' : 'LEDGER METADATA', 
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.primary),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit_note, color: theme.colorScheme.primary),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!_isEditing) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Title Descriptor', style: TextStyle(fontSize: 11, color: Colors.white38)),
                subtitle: Text(widget.transaction.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Value Amount', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      subtitle: Text(
                        '$_selectedCurrency ${widget.transaction.amount.toStringAsFixed(0)}', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _isTransfer ? Colors.blueAccent : (_isExpense ? Colors.redAccent : Colors.greenAccent)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Flow Strategy', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      subtitle: Text(_isTransfer ? 'Transfer 🔄' : (_isExpense ? 'Expense 🛑' : 'Income 💰'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DiskListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isTransfer ? 'Debited Account' : 'Source Wallet', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      subtitle: Text(widget.transaction.account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isTransfer ? 'Credited Account' : 'Budget Envelope', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      subtitle: Text(_isTransfer ? (widget.transaction.toAccount ?? 'None') : widget.transaction.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              if (widget.transaction.currency != 'INR')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Standardized Cost Evaluation (Base Currency)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  subtitle: Text('₹${widget.transaction.baseAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                ),
              const SizedBox(height: 24),
            ] else ...[
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
                decoration: const InputDecoration(labelText: 'Payee Descriptor', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount Balance', border: OutlineInputBorder()),
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
                      decoration: InputDecoration(border: const OutlineInputBorder(), labelText: _isTransfer ? 'From Account' : 'Account Source'),
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
                  child: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

class DiskListTile extends StatelessWidget {
  final Widget title;
  final Widget subtitle;
  final EdgeInsetsGeometry contentPadding;
  const DiskListTile({super.key, required this.title, required this.subtitle, required this.contentPadding});
  @override
  Widget build(BuildContext context) {
    return ListTile(contentPadding: contentPadding, title: title, subtitle: subtitle);
  }
}