import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:another_telephony/telephony.dart'; // Modern Android compatible fork

import 'transaction_model.dart';
import 'budget_category_model.dart'; 
import 'dashboard_screen.dart'; 

/// 🔥 Top-level global function required to capture SMS events 
/// when the app is completely closed or running in the background.
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  debugPrint("📩 Background SMS Intercepted: ${message.body}");
  
  // Since the background worker runs in an isolated native engine thread,
  // we initialize Hive here to safely save the transaction even when closed.
  await Hive.initFlutter('test_db');
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetCategoryAdapter());
  
  final box = await Hive.openBox<Transaction>('transactions');
  
  // TODO: Run your transaction parsing regex engine logic directly here
  // Example: final tx = parseSms(message.body); if (tx != null) box.add(tx);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive Storage
  await Hive.initFlutter('test_db');
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetCategoryAdapter()); 

  runApp(
    const ProviderScope(
      child: FilousApp(),
    ),
  );
}

class FilousApp extends StatefulWidget {
  const FilousApp({super.key});

  @override
  State<FilousApp> createState() => _FilousAppState();
}

class _FilousAppState extends State<FilousApp> {
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _initIncomingSmsListener();
  }

  /// Hook up the system message listener streams
  void _initIncomingSmsListener() {
    telephony.listenIncomingSms(
      // Triggered when a message arrives while you are looking at the app
      onNewMessage: (SmsMessage message) {
        debugPrint("⚡ Foreground SMS Intercepted: ${message.body}");
        
        // Feed the message content straight into your Riverpod state notifier channel
        // context.read(transactionProvider.notifier).parseIncomingSMS(message.body);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

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
      home: const DashboardScreen(),
    );
  }
}