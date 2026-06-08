import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive and register our generated binary adapter
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  
  // Open a storage box for Filous transactions
  await Hive.openBox<Transaction>('filous_transactions');

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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // High-contrast, default scheme if dynamic coloring isn't on
        const fallbackDarkScheme = ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
          surface: Color(0xFF121212),
        );

        return MaterialApp(
          title: 'Filous',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? fallbackDarkScheme,
            scaffoldBackgroundColor: darkDynamic?.surface ?? Colors.black,
          ),
          home: const FilousDashboard(),
        );
      },
    );
  }
}

class FilousDashboard extends StatelessWidget {
  const FilousDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FILOUS', 
          style: TextStyle(fontWeight: FontWeight.black, letterSpacing: 1.5, fontSize: 20)
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Balance Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BALANCE', 
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹ 0.00', 
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 38, fontWeight: FontWeight.black)
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'RECENT TRANSACTIONS', 
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'No transactions logged yet.\nTap below to register an entry.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, height: 1.5),
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Input panel trigger goes here
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0, // Flat and modern
        label: const Text('Log Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }
}