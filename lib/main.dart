import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'transaction_model.dart';
import 'budget_category_model.dart'; 
import 'dashboard_screen.dart'; // 🔥 This MUST match your file name exactly

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter('test_db');
  
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetCategoryAdapter()); 
  
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
          seedColor: const Color(0xFF6366F1), 
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A), 
      ),
      home: DashboardScreen(),
    );
  }
}