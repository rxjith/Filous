import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:another_telephony/telephony.dart';

import 'backup_service.dart';
import 'transaction_model.dart';
import 'budget_category_model.dart'; 
import 'dashboard_screen.dart'; 
import 'transaction_provider.dart';
import 'sms_transaction_parser.dart';
import 'sms_permission_page.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'theme_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

/// 🔥 Top-level global function required to capture SMS events 
/// when the app is completely closed or running in the background.
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  debugPrint("📩 Background SMS Intercepted: ${message.body}");
  
  // Since the background worker runs in an isolated native engine thread,
  // we initialize Hive here to safely save the transaction even when closed.
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetCategoryAdapter());
  
  final box = await Hive.openBox<Transaction>('transactions_box');
  final parsedTransaction = SmsTransactionParser.parseIncomingMessage(message);
  if (parsedTransaction == null) return;

  box.put(parsedTransaction.id, parsedTransaction);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  // Initialize Hive Storage
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetCategoryAdapter()); 
  await Hive.openBox('app_settings');

  runApp(
    const ProviderScope(
      child: FilousApp(),
    ),
  );
}

class FilousApp extends ConsumerStatefulWidget {
  const FilousApp({super.key});

  @override
  ConsumerState<FilousApp> createState() => _FilousAppState();
}

class _FilousAppState extends ConsumerState<FilousApp>
    with WidgetsBindingObserver {
  static const String _hasSeenSmsPermissionExplainerKey =
      'has_seen_sms_permission_explainer';
  static const String _smsAutoLoggingEnabledKey = 'sms_auto_logging_enabled';
  static const String _isOnboardedKey = 'is_onboarded';

  final Telephony telephony = Telephony.instance;
  late final Box _settingsBox;
  bool _isBootstrapping = true;
  bool _showSmsPermissionExplainer = false;
  bool _listenerStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsBox = Hive.box('app_settings');
    _bootstrapSmsFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrapSmsFlow() async {
    final hasSeenExplainer =
        _settingsBox.get(_hasSeenSmsPermissionExplainerKey, defaultValue: false) as bool;
    final smsAutoLoggingEnabled =
        _settingsBox.get(_smsAutoLoggingEnabledKey, defaultValue: false) as bool;

    if (!hasSeenExplainer) {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _showSmsPermissionExplainer = true;
      });
      return;
    }

    if (smsAutoLoggingEnabled) {
      await _requestSmsPermissionAndStartListening(markExplainerSeen: false);
    }

    try {
      await BackupService.runScheduledBackupIfDue();
    } catch (error) {
      debugPrint('Scheduled backup skipped: $error');
    }

    if (!mounted) return;
    setState(() {
      _isBootstrapping = false;
      _showSmsPermissionExplainer = false;
    });
  }

  Future<void> _requestSmsPermissionAndStartListening({
    required bool markExplainerSeen,
  }) async {
    if (markExplainerSeen) {
      await _settingsBox.put(_hasSeenSmsPermissionExplainerKey, true);
    }

    try {
      final permissionGranted = await telephony.requestPhoneAndSmsPermissions;
      debugPrint('SMS permission request result: $permissionGranted');
      
      if (permissionGranted != true) {
        await _settingsBox.put(_smsAutoLoggingEnabledKey, false);
        debugPrint('SMS permissions were denied; auto logging is disabled.');
        return;
      }

      await _settingsBox.put(_smsAutoLoggingEnabledKey, true);
      _startIncomingSmsListener();
    } catch (e) {
      debugPrint('Error requesting SMS permissions: $e');
    }
  }

  void _startIncomingSmsListener() {
    if (_listenerStarted) return;
    _listenerStarted = true;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        debugPrint("⚡ Foreground SMS Intercepted: ${message.body}");
        ref.read(transactionProvider.notifier).ingestIncomingSms(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  Future<void> _handleSmsPermissionAccepted() async {
    await _requestSmsPermissionAndStartListening(markExplainerSeen: true);
    if (!mounted) return;

    setState(() {
      _isBootstrapping = false;
      _showSmsPermissionExplainer = false;
    });
  }

  Future<void> _handleSmsPermissionSkipped() async {
    await _settingsBox.put(_hasSeenSmsPermissionExplainerKey, true);
    await _settingsBox.put(_smsAutoLoggingEnabledKey, false);
    if (!mounted) return;

    setState(() {
      _isBootstrapping = false;
      _showSmsPermissionExplainer = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 🔥 Refresh the UI state from storage whenever the app comes back to focus
      // This picks up transactions saved by the backgroundMessageHandler
      ref.read(transactionProvider.notifier).reloadFromStorage();
      
      BackupService.runScheduledBackupIfDue().catchError((error) {
        debugPrint('Scheduled backup skipped on resume: $error');
        return false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (themeState.themeSource == ThemeSource.dynamic && lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: themeState.presetColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: themeState.presetColor,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Filous',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: lightColorScheme.surface,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: const Color(0xFF0F0F1A), 
          ),
          themeMode: themeState.themeMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (snapshot.hasData) {
                return ValueListenableBuilder(
                  valueListenable: _settingsBox.listenable(keys: [_isOnboardedKey]),
                  builder: (context, Box box, _) {
                    final isOnboarded = box.get(_isOnboardedKey, defaultValue: false) as bool;

                    if (!isOnboarded) {
                      return const OnboardingScreen();
                    }

                    return _isBootstrapping
                        ? const Scaffold(
                            body: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _showSmsPermissionExplainer
                            ? SmsPermissionPage(
                                onAllow: _handleSmsPermissionAccepted,
                                onSkip: _handleSmsPermissionSkipped,
                              )
                            : const DashboardScreen();
                  },
                );
              }
              
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
