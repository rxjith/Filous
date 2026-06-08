import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'transaction_model.dart';
import 'budget_category_model.dart'; // 🔥 Import your brand new custom category schema
import 'dashboard_screen.dart';       // Adjust this import path depending on where your main screen lives

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Fire up local Hive subsystem 
  await Hive.initFlutter('test_db');
  
  // 2. Register structural database adapters cleanly
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(BudgetCategoryAdapter()); // 🔥 Essential: Tells Hive how to unpack your category limits
  
  runApp(
    const ProviderScope(
      child: FilousApp(),
    ),
  );
}

class FilousApp extends StatelessWidget {
  const FilousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Filous',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Clean Indigo accent hue
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A), // Sleek OLED midnight tone
      ),
      home: const FilousApp(),
      home: DashboardScreen(),
    );
  }
}