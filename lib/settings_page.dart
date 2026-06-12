import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'backup_service.dart';
import 'transaction_provider.dart';
import 'theme_provider.dart';
import 'app_mode_provider.dart';
import 'onboarding_screen.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late BackupFrequency _selectedFrequency;
  bool _isBusy = false;
  String? _backupDirectoryUri;
  String? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = BackupService.savedFrequency;
    _backupDirectoryUri = BackupService.backupDirectoryUri;
    _lastBackupAt = BackupService.lastBackupAt?.toLocal().toString();
  }

  Future<void> _pickBackupFolder() async {
    setState(() => _isBusy = true);
    try {
      final uri = await BackupService.chooseBackupDirectory();
      if (!mounted) return;
      setState(() {
        _backupDirectoryUri = uri ?? _backupDirectoryUri;
      });
      if (uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup folder selected.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick backup folder: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveFrequency(BackupFrequency frequency) async {
    setState(() {
      _selectedFrequency = frequency;
    });
    await BackupService.saveFrequency(frequency);
  }

  Future<void> _createManualBackup() async {
    setState(() => _isBusy = true);
    try {
      await BackupService.createManualBackupWithPicker();
      _lastBackupAt = BackupService.lastBackupAt?.toLocal().toString();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved successfully to the selected file.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isBusy = true);
    try {
      final restored = await BackupService.restoreFromChosenBackup();
      if (!mounted) return;
      if (!restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ref.read(transactionProvider.notifier).reloadFromStorage();
      setState(() {
        _selectedFrequency = BackupService.savedFrequency;
        _backupDirectoryUri = BackupService.backupDirectoryUri;
        _lastBackupAt = BackupService.lastBackupAt?.toLocal().toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // Back to dashboard, which will then show LoginScreen
      }
    }
  }

  Future<void> _openAutostartSettings() async {
    final List<Map<String, String>> intents = [
      {'package': 'com.miui.securitycenter', 'component': 'com.miui.permcenter.autostart.AutoStartManagementActivity'},
      {'package': 'com.letv.android.letvsafe', 'component': 'com.letv.android.letvsafe.AutobootManageActivity'},
      {'package': 'com.huawei.systemmanager', 'component': 'com.huawei.systemmanager.optimize.process.ProtectActivity'},
      {'package': 'com.coloros.safecenter', 'component': 'com.coloros.safecenter.permission.startup.StartupAppListActivity'},
      {'package': 'com.oppo.safe', 'component': 'com.oppo.safe.permission.startup.StartupAppListActivity'},
      {'package': 'com.iqoo.secure', 'component': 'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'},
      {'package': 'com.vivo.permissionmanager', 'component': 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'},
      {'package': 'com.samsung.android.lool', 'component': 'com.samsung.android.sm.ui.battery.BatteryActivity'},
    ];

    bool launched = false;
    for (var intentData in intents) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: intentData['package'],
          componentName: intentData['component'],
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        launched = true;
        break;
      } catch (e) {
        debugPrint('Intent failed: ${intentData['package']}');
      }
    }
    if (!launched) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final appMode = ref.watch(appModeProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      child: Icon(Icons.person, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isAnonymous == true ? 'Guest User' : (user?.email ?? 'Filous User'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user?.isAnonymous == true ? 'Limited cloud features' : 'Active Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme Source', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Dynamic')),
                        selected: themeState.themeSource == ThemeSource.dynamic,
                        onSelected: (val) => themeNotifier.setThemeSource(ThemeSource.dynamic),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Presets')),
                        selected: themeState.themeSource == ThemeSource.preset,
                        onSelected: (val) => themeNotifier.setThemeSource(ThemeSource.preset),
                      ),
                    ),
                  ],
                ),
                if (themeState.themeSource == ThemeSource.preset) ...[
                  const SizedBox(height: 16),
                  const Text('Select Preset Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      _ColorCircle(
                        color: const Color(0xFF6366F1), // Indigo
                        selected: themeState.presetColor == const Color(0xFF6366F1),
                        onTap: () => themeNotifier.setPresetColor(const Color(0xFF6366F1)),
                      ),
                      _ColorCircle(
                        color: const Color(0xFFE11D48), // Rose
                        selected: themeState.presetColor == const Color(0xFFE11D48),
                        onTap: () => themeNotifier.setPresetColor(const Color(0xFFE11D48)),
                      ),
                      _ColorCircle(
                        color: const Color(0xFFF59E0B), // Amber
                        selected: themeState.presetColor == const Color(0xFFF59E0B),
                        onTap: () => themeNotifier.setPresetColor(const Color(0xFFF59E0B)),
                      ),
                      _ColorCircle(
                        color: const Color(0xFF10B981), // Emerald
                        selected: themeState.presetColor == const Color(0xFF10B981),
                        onTap: () => themeNotifier.setPresetColor(const Color(0xFF10B981)),
                      ),
                      _ColorCircle(
                        color: const Color(0xFF8B5CF6), // Violet
                        selected: themeState.presetColor == const Color(0xFF8B5CF6),
                        onTap: () => themeNotifier.setPresetColor(const Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<ThemeMode>(
                  value: themeState.themeMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ThemeMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(mode.name[0].toUpperCase() + mode.name.substring(1).toLowerCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) themeNotifier.setThemeMode(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'APP EXPERIENCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tracking Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Current: ${appMode == AppMode.budget ? "Budget Tracker" : "Spending Tracker"}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Switch App Mode?'),
                          content: const Text('Switching modes will change how your dashboard looks. You can switch back anytime.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SWITCH')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final newMode = appMode == AppMode.budget ? AppMode.spending : AppMode.budget;
                        ref.read(appModeProvider.notifier).state = newMode;
                        Hive.box('app_settings').put('app_mode', newMode.index);
                      }
                    },
                    child: Text('Switch to ${appMode == AppMode.budget ? "Spending" : "Budget"} Tracker'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'BACKGROUND RELIABILITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Battery & Background Logging', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'To ensure SMS transactions are logged even when the app is closed, please disable battery optimization.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Background Logging'),
                          content: const Text('This will open your system settings. Please find "Filous" and set it to "Unrestricted" or "Not Optimized".'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OPEN SETTINGS')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await Permission.ignoreBatteryOptimizations.request();
                        if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
                          await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                        }
                      }
                    },
                    icon: const Icon(Icons.battery_saver),
                    label: const Text('Disable Battery Optimization'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openAutostartSettings,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Enable Autostart'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'BACKUP & RESTORE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup Frequency',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BackupFrequency.values.map((frequency) {
                    return ChoiceChip(
                      label: Text(frequency.label),
                      selected: _selectedFrequency == frequency,
                      onSelected: (_) => _saveFrequency(frequency),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Automatic backups run when the app is opened after the selected interval has passed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup Folder',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  _backupDirectoryUri == null
                      ? 'No backup folder selected yet.'
                      : _backupDirectoryUri!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickBackupFolder,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choose Backup Folder'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual Actions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  _lastBackupAt == null
                      ? 'No backup has been created yet.'
                      : 'Last backup: $_lastBackupAt',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _createManualBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Create Backup Now'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _restoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Restore From Backup File'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}
