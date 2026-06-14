import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class SmsPermissionPage extends StatefulWidget {
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const SmsPermissionPage({
    super.key,
    required this.onAllow,
    required this.onSkip,
  });

  @override
  State<SmsPermissionPage> createState() => _SmsPermissionPageState();
}

class _SmsPermissionPageState extends State<SmsPermissionPage> with WidgetsBindingObserver {
  bool _isSmsGranted = false;
  bool _isBatteryOptimDisabled = false;
  bool _isAutostartEnabled = false; // Note: Hard to detect reliably on Android

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final smsStatus = await Permission.sms.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {
        _isSmsGranted = smsStatus.isGranted;
        _isBatteryOptimDisabled = batteryStatus;
      });
    }
  }

  Future<void> _openAutostartSettings() async {
    // Common vendor-specific autostart intents
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
        setState(() => _isAutostartEnabled = true);
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
    final allCriticalGranted = _isSmsGranted && _isBatteryOptimDisabled;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.sms_outlined,
                  size: 34,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Enable Automated Logging',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To track transactions in the background reliably, we need a few permissions.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.78),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Required Steps',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _StepAction(
                icon: Icons.sms_outlined,
                title: 'SMS Permission',
                subtitle: 'Read transaction alerts automatically.',
                onTap: widget.onAllow,
                buttonLabel: _isSmsGranted ? 'GRANTED' : 'GRANT',
                isGranted: _isSmsGranted,
              ),
              const SizedBox(height: 12),
              _StepAction(
                icon: Icons.battery_saver_outlined,
                title: 'Battery Optimization',
                subtitle: 'Prevent Android from stopping the listener.',
                onTap: () async {
                  await Permission.ignoreBatteryOptimizations.request();
                  if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
                    await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                  }
                  _checkPermissions();
                },
                buttonLabel: _isBatteryOptimDisabled ? 'DISABLED' : 'DISABLE',
                isGranted: _isBatteryOptimDisabled,
              ),
              const SizedBox(height: 12),
              _StepAction(
                icon: Icons.rocket_launch_outlined,
                title: 'Autostart',
                subtitle: 'Allow listener to start on boot.',
                onTap: _openAutostartSettings,
                buttonLabel: _isAutostartEnabled ? 'ENABLED' : 'ENABLE',
                isGranted: _isAutostartEnabled,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (!allCriticalGranted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please grant all required permissions for best results.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    widget.onSkip();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allCriticalGranted 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    foregroundColor: allCriticalGranted 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    allCriticalGranted ? 'GET STARTED' : 'CONTINUE ANYWAY',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String buttonLabel;
  final bool isGranted;

  const _StepAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.buttonLabel,
    this.isGranted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted 
            ? theme.colorScheme.primary.withOpacity(0.05)
            : theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? theme.colorScheme.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : icon, 
            size: 24, 
            color: isGranted ? Colors.greenAccent : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          TextButton(
            onPressed: isGranted ? null : onTap,
            child: Text(
              buttonLabel, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isGranted ? Colors.greenAccent : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
