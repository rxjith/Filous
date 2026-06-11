import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_provider.dart';

class ManageCategoriesModal extends ConsumerStatefulWidget {
  const ManageCategoriesModal({super.key});

  @override
  ConsumerState<ManageCategoriesModal> createState() => _ManageCategoriesModalState();
}

class _ManageCategoriesModalState extends ConsumerState<ManageCategoriesModal> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  String? _editingCategoryName;

  void _submitCategory() {
    final name = _nameController.text.trim();
    final limit = double.tryParse(_limitController.text) ?? 0.0;

    if (name.isEmpty || limit <= 0) return;

    ref.read(transactionProvider.notifier).addOrUpdateCategory(name, limit);
    setState(() {
      _nameController.clear();
      _limitController.clear();
    });
  }

  void _startEditingCategory(String name, double currentLimit) {
    setState(() {
      _editingCategoryName = name;
      _nameController.text = name;
      _limitController.text = currentLimit.toStringAsFixed(0);
    });
  }

  void _cancelEditingCategory() {
    setState(() {
      _editingCategoryName = null;
      _nameController.clear();
      _limitController.clear();
    });
  }

  void _saveEditedCategory() {
    final name = _editingCategoryName;
    final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;

    if (name == null || limit <= 0) return;

    ref.read(transactionProvider.notifier).addOrUpdateCategory(name, limit);
    setState(() {
      _editingCategoryName = null;
      _nameController.clear();
      _limitController.clear();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgets = ref.watch(transactionProvider.notifier).categoryBudgets;
    final budgetEntries = budgets.entries.toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MANAGE ENVELOPE BUDGETS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    readOnly: _editingCategoryName != null,
                    decoration: InputDecoration(
                      labelText: _editingCategoryName == null ? 'Category Title' : 'Envelope Name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Limit (₹)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                if (_editingCategoryName == null)
                  IconButton.filled(
                    onPressed: _submitCategory,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _cancelEditingCategory,
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel edit',
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: _saveEditedCategory,
                        icon: const Icon(Icons.check),
                        tooltip: 'Save budget',
                        style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ACTIVE ENVELOPES', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
  
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: budgetEntries.length,
                itemBuilder: (ctx, idx) {
                  final entry = budgetEntries[idx];
                  final catName = entry.key;
                  final catLimit = entry.value;
  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${catLimit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 20),
                          tooltip: 'Edit budget',
                          onPressed: () => _startEditingCategory(catName, catLimit),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            ref.read(transactionProvider.notifier).deleteCategory(catName);
                            setState(() {
                              if (_editingCategoryName == catName) {
                                _editingCategoryName = null;
                                _nameController.clear();
                                _limitController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
