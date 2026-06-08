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
  late String _selectedCategory;
  late String _selectedAccount;
  bool _isEditing = false; // Toggle state between READ and UPDATE modes

  final List<String> _categories = ['Food', 'Transport', 'Leisure', 'Subscriptions', 'Misc'];
  final List<String> _accounts = ['Cash', 'Bank', 'Credit'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(0));
    _isExpense = widget.transaction.isExpense;
    _selectedCategory = widget.transaction.category;
    _selectedAccount = widget.transaction.account;
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

    final updatedTx = Transaction(
      id: widget.transaction.id, // Retain original unique database key
      title: enteredTitle,
      amount: enteredAmount,
      date: widget.transaction.date, // Retain original transaction timestamp
      category: _selectedCategory,
      isExpense: _isExpense,
      account: _selectedAccount,
    );

    ref.read(transactionProvider.notifier).updateTransaction(updatedTx);
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
                  icon: Icon(_isEditing ? Icons.close : Icons.edit, color: theme.colorScheme.primary),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!_isEditing) ...[
              // 📖 READ MODE UI LAYOUT
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Description', style: TextStyle(fontSize: 12, color: Colors.white38)),
                subtitle: Text(widget.transaction.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Amount', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text('₹${widget.transaction.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.transaction.isExpense ? Colors.redAccent : Colors.greenAccent)),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Flow Type', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(widget.transaction.isExpense ? 'Expense 🛑' : 'Income 💰', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Category Envelope', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(widget.transaction.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wallet/Account', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      subtitle: Text(widget.transaction.account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              // 📝 UPDATE MODE FORM LAYOUT
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _isExpense,
                      onSelected: (val) => setState(() => _isExpense = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: !_isExpense,
                      onSelected: (val) => setState(() => _isExpense = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Store / Source', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category'),
                      items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAccount,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Wallet/Account'),
                      items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
                      onChanged: (val) => setState(() => _selectedAccount = val!),
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