import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_service.dart';
import 'transaction_provider.dart';

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
      final result = await BackupService.createManualBackupWithPicker();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
