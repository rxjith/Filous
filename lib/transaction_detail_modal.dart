import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  
  // State variables tracking configuration flags
  late bool _isExpense;
  late bool _isTransfer;
  
  String? _selectedCategory; 
  late String _selectedAccount;
  late String _selectedToAccount;
  late String _selectedRecurrence;
  late String _selectedCurrency;
  late DateTime _selectedDate;
  bool _isEditing = false; 

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
    _selectedDate = widget.transaction.date;
    
    // Safety check: ensure 'To Account' doesn't accidentally initialize identical to source account
    _selectedToAccount = widget.transaction.toAccount ?? 
        (_selectedAccount == 'Bank' ? 'Credit' : 'Bank');
        
    _selectedRecurrence = widget.transaction.recurrence;
    _selectedCurrency = widget.transaction.currency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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

  void _saveChanges() {
    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (enteredTitle.isEmpty || enteredAmount <= 0) return;

    // Retrieve active exchange rates straight from structural provider memory
    double rateMultiplier = ref.read(transactionProvider.notifier).activeRates[_selectedCurrency] ?? 1.0;

    final updatedTx = Transaction(
      id: widget.transaction.id, 
      title: enteredTitle,
      amount: enteredAmount,
      date: _selectedDate, 
      category: _isTransfer ? 'Transfer' : (_selectedCategory ?? 'Misc'),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useCompactLayout = screenWidth < 420;
    
    // 1. Fetch real-time live envelopes configuration from Hive
    final activeCategories = ref.watch(transactionProvider.notifier).categoryBudgets.keys.toList();

    // 2. 🔥 CRITICAL SAFETY FIXED: Safe-fallback evaluation for dynamic categories.
    // If the category was deleted or is missing, gracefully realign dropdown to prevent standard assertion failures.
    if (!_isTransfer && (_selectedCategory == null || !activeCategories.contains(_selectedCategory))) {
      if (activeCategories.contains('Misc')) {
        _selectedCategory = 'Misc';
      } else if (activeCategories.isNotEmpty) {
        _selectedCategory = activeCategories.first;
      } else {
        _selectedCategory = null; 
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Head Section Panel Layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'MODIFY ENTRIES' : 'TRANSACTION DETAIL', 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.2, 
                      color: theme.colorScheme.primary
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.close : Icons.edit_note, color: theme.colorScheme.primary),
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- READ ONLY PRESENTATION STACK ---
              if (!_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Category', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        subtitle: Text(
                          _isTransfer ? 'Transfer' : widget.transaction.category, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Amount', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        subtitle: Text(
                          '${widget.transaction.currency == 'INR' ? '₹' : widget.transaction.currency} ${widget.transaction.amount.toStringAsFixed(0)}', 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w900, 
                            color: _isTransfer 
                                ? Colors.amberAccent 
                                : (_isExpense ? Colors.redAccent : Colors.greenAccent)
                          ),
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
                        title: const Text('Date', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(widget.transaction.date), 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Note', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        subtitle: Text(
                          widget.transaction.title, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
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
                        title: Text(_isTransfer ? 'Debited Account' : 'Account', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        subtitle: Text(widget.transaction.account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (_isTransfer)
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Credited Account', style: TextStyle(fontSize: 11, color: Colors.white38)),
                          subtitle: Text(
                            widget.transaction.toAccount ?? 'None', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.transaction.currency != 'INR')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Base Amount (INR)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    subtitle: Text('₹${widget.transaction.baseAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  ),
                const SizedBox(height: 24),
              ] 
              
              // --- EDITABLE INTERACTIVE FORM STACK ---
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Expense')),
                        selected: _isExpense && !_isTransfer,
                        selectedColor: Colors.redAccent.withOpacity(0.2),
                        onSelected: (val) => setState(() { _isExpense = true; _isTransfer = false; }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Income')),
                        selected: !_isExpense && !_isTransfer,
                        selectedColor: Colors.greenAccent.withOpacity(0.2),
                        onSelected: (val) => setState(() { _isExpense = false; _isTransfer = false; }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Transfer')),
                        selected: _isTransfer,
                        selectedColor: Colors.amberAccent.withOpacity(0.2),
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
                  decoration: const InputDecoration(labelText: 'Description / Note', border: OutlineInputBorder()),
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
                if (useCompactLayout) ...[
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Currency',
                    ),
                    items: _currencies
                        .map((cur) => DropdownMenuItem(value: cur, child: Text(cur)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCurrency = val!),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Currency',
                          ),
                          items: _currencies
                              .map((cur) => DropdownMenuItem(value: cur, child: Text(cur)))
                              .toList(),
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
                        isExpanded: true,
                        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: _isTransfer ? 'From Account' : 'Account'),
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
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'To Account'),
                          items: _accounts.where((a) => a != _selectedAccount).map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
                          onChanged: (val) => setState(() => _selectedToAccount = val!),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isTransfer && useCompactLayout) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Category',
                    ),
                    items: activeCategories.isEmpty
                        ? [const DropdownMenuItem(value: 'Misc', child: Text('Misc'))]
                        : activeCategories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRecurrence,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Recurrence',
                    ),
                    items: _recurrences
                        .map((rec) => DropdownMenuItem(value: rec, child: Text(rec)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRecurrence = val!),
                  ),
                ] else
                  Row(
                    children: [
                      if (!_isTransfer) ...[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Category',
                            ),
                            items: activeCategories.isEmpty
                                ? [const DropdownMenuItem(value: 'Misc', child: Text('Misc'))]
                                : activeCategories
                                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                    .toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRecurrence,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Recurrence',
                          ),
                          items: _recurrences
                              .map((rec) => DropdownMenuItem(value: rec, child: Text(rec)))
                              .toList(),
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
      ),
    );
  }
}

