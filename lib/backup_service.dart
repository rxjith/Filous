import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'budget_category_model.dart';
import 'transaction_model.dart';

enum BackupFrequency {
  daily('Daily'),
  weekly('Weekly'),
  annually('Annually');

  const BackupFrequency(this.label);
  final String label;

  Duration? get interval {
    switch (this) {
      case BackupFrequency.daily:
        return const Duration(days: 1);
      case BackupFrequency.weekly:
        return const Duration(days: 7);
      case BackupFrequency.annually:
        return const Duration(days: 365);
    }
  }

  static BackupFrequency fromStoredValue(String? value) {
    return BackupFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => BackupFrequency.weekly,
    );
  }
}

class BackupService {
  BackupService._();

  static const MethodChannel _storageChannel =
      MethodChannel('filous/storage_access');

  static const String backupFrequencyKey = 'backup_frequency';
  static const String backupDirectoryUriKey = 'backup_directory_uri';
  static const String lastBackupAtKey = 'last_backup_at';

  static Box get _settingsBox => Hive.box('app_settings');
  static Box<Transaction> get _transactionsBox => Hive.box<Transaction>('transactions_box');
  static Box<BudgetCategory> get _categoriesBox => Hive.box<BudgetCategory>('categories_box');

  static BackupFrequency get savedFrequency {
    final storedValue = _settingsBox.get(backupFrequencyKey) as String?;
    return BackupFrequency.fromStoredValue(storedValue);
  }

  static String? get backupDirectoryUri =>
      _settingsBox.get(backupDirectoryUriKey) as String?;

  static DateTime? get lastBackupAt {
    final value = _settingsBox.get(lastBackupAtKey) as String?;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Future<void> saveFrequency(BackupFrequency frequency) {
    return _settingsBox.put(backupFrequencyKey, frequency.name);
  }

  static Future<String?> chooseBackupDirectory() async {
    final uri =
        await _storageChannel.invokeMethod<String>('pickBackupDirectory');
    if (uri != null && uri.isNotEmpty) {
      await _settingsBox.put(backupDirectoryUriKey, uri);
    }
    return uri;
  }

  static Future<String> createBackup({
    required String reason,
  }) async {
    final treeUri = backupDirectoryUri;
    if (treeUri == null || treeUri.isEmpty) {
      throw StateError('Choose a backup folder before creating a backup.');
    }

    final payload = jsonEncode(_createBackupPayload(reason: reason));
    final fileName = _buildBackupFileName();
    final createdUri = await _storageChannel.invokeMethod<String>(
      'writeBackupFile',
      {
        'treeUri': treeUri,
        'fileName': fileName,
        'content': payload,
      },
    );

    await _settingsBox.put(lastBackupAtKey, DateTime.now().toIso8601String());
    return createdUri ?? fileName;
  }

  static Future<String> createManualBackupWithPicker() async {
    final payload = jsonEncode(_createBackupPayload(reason: 'manual'));
    final fileName = _buildBackupFileName();
    final createdUri = await _storageChannel.invokeMethod<String>(
      'saveBackupFile',
      {
        'fileName': fileName,
        'content': payload,
      },
    );

    if (createdUri == null || createdUri.isEmpty) {
      throw StateError('Backup save was cancelled.');
    }

    await _settingsBox.put(lastBackupAtKey, DateTime.now().toIso8601String());
    return createdUri;
  }

  static Future<bool> runScheduledBackupIfDue() async {
    final treeUri = backupDirectoryUri;
    if (treeUri == null || treeUri.isEmpty) return false;

    final interval = savedFrequency.interval;
    final previousBackup = lastBackupAt;
    if (interval != null &&
        previousBackup != null &&
        DateTime.now().difference(previousBackup) < interval) {
      return false;
    }

    await createBackup(reason: 'scheduled_${savedFrequency.name}');
    return true;
  }

  static Future<bool> restoreFromChosenBackup() async {
    final content =
        await _storageChannel.invokeMethod<String>('pickRestoreFile');
    if (content == null || content.isEmpty) return false;

    final raw = jsonDecode(content);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Backup file is not a valid Filous backup.');
    }

    final transactions = (raw['transactions'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final categories = (raw['categories'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final settings =
        Map<String, dynamic>.from(
          raw['settings'] as Map? ?? const <String, dynamic>{},
        );

    await _transactionsBox.clear();
    await _categoriesBox.clear();

    // Batch process categories
    final Map<String, BudgetCategory> categoryModels = {};
    for (final category in categories) {
      final name = category['name'] as String;
      categoryModels[name] = BudgetCategory(
        name: name,
        monthlyLimit: (category['monthlyLimit'] as num).toDouble(),
      );
    }
    await _categoriesBox.putAll(categoryModels);

    // Batch process transactions
    final Map<String, Transaction> transactionModels = {};
    for (final tx in transactions) {
      final id = tx['id'] as String;
      transactionModels[id] = Transaction(
        id: id,
        title: tx['title'] as String,
        amount: (tx['amount'] as num).toDouble(),
        date: DateTime.parse(tx['date'] as String),
        category: tx['category'] as String,
        account: tx['account'] as String,
        isExpense: tx['isExpense'] as bool,
        isTransfer: tx['isTransfer'] as bool? ?? false,
        toAccount: tx['toAccount'] as String?,
        recurrence: tx['recurrence'] as String? ?? 'None',
        currency: tx['currency'] as String? ?? 'INR',
        exchangeRate: (tx['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
    }
    await _transactionsBox.putAll(transactionModels);

    // Restore settings
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
    
    await _settingsBox.put(lastBackupAtKey, DateTime.now().toIso8601String());
    
    // Explicitly flush all boxes to ensure data is safe before potential app reload
    await Future.wait([
      _transactionsBox.flush(),
      _categoriesBox.flush(),
      _settingsBox.flush(),
    ]);

    return true;
  }

  static Map<String, dynamic> _createBackupPayload({
    required String reason,
  }) {
    return {
      'meta': {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'reason': reason,
      },
      'transactions': _transactionsBox.values.map(_serializeTransaction).toList(),
      'categories': _categoriesBox.values.map(_serializeCategory).toList(),
      'settings': _exportedSettings(),
    };
  }

  static Map<String, dynamic> _serializeTransaction(Transaction tx) {
    return {
      'id': tx.id,
      'title': tx.title,
      'amount': tx.amount,
      'date': tx.date.toIso8601String(),
      'category': tx.category,
      'account': tx.account,
      'isExpense': tx.isExpense,
      'isTransfer': tx.isTransfer,
      'toAccount': tx.toAccount,
      'recurrence': tx.recurrence,
      'currency': tx.currency,
      'exchangeRate': tx.exchangeRate,
    };
  }

  static Map<String, dynamic> _serializeCategory(BudgetCategory category) {
    return {
      'name': category.name,
      'monthlyLimit': category.monthlyLimit,
    };
  }

  static Map<String, dynamic> _exportedSettings() {
    return {
      backupFrequencyKey: _settingsBox.get(backupFrequencyKey, defaultValue: BackupFrequency.weekly.name),
      'has_seen_sms_permission_explainer':
          _settingsBox.get('has_seen_sms_permission_explainer', defaultValue: false),
      'sms_auto_logging_enabled':
          _settingsBox.get('sms_auto_logging_enabled', defaultValue: false),
    };
  }

  static String _buildBackupFileName() {
    final now = DateTime.now();
    final safeTimestamp = now.toIso8601String().replaceAll(':', '-');
    return 'filous_backup_$safeTimestamp.json';
  }
}
