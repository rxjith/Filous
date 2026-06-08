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

  void _submitCategory() {
    final name = _nameController.text.trim();
    final limit = double.tryParse(_limitController.text) ?? 0.0;

    if (name.isEmpty || limit <= 0) return;

    ref.read(transactionProvider.notifier).addOrUpdateCategory(name, limit);
    _nameController.clear();
    _limitController.clear();
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

    return Padding(
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
                  decoration: const InputDecoration(labelText: 'Category Title', border: OutlineInputBorder()),
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
              IconButton.filled(
                onPressed: _submitCategory,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('ACTIVE ENVELOPES', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: budgets.length,
              itemBuilder: (ctx, idx) {
                final catName = budgets.keys.elementAt(idx);
                final catLimit = budgets.values.elementAt(idx);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${catLimit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => ref.read(transactionProvider.notifier).deleteCategory(catName),
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
    );
  }
}