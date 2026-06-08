import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_categories_modal.dart'; // 🔥 Pull in your custom envelope manager sheet
import 'add_transaction_modal.dart';   // Pull in your transaction form modal

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FILOUS DASHBOARD', 
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 24),
              tooltip: 'Configure Envelopes',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => const ManageCategoriesModal(), // 🔥 Pops up your custom creation engine
              ),
            ),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Your main transactions overview list layout stays right here!',
          style: TextStyle(color: Colors.white54),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const AddTransactionModal(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}