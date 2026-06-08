import 'package:flutter/material.dart';
import 'manage_categories_modal.dart'; // 🔥 Pull in your custom envelope manager sheet

// Drop this structural AppBar directly into your active Scaffold build block:
@override
Widget build(BuildContext context) {
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
              backgroundColor: Theme.of(context).colorScheme.surface,
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
      child: Text('Your main transactions overview list layout stays right here!'),
    ),
  );
}