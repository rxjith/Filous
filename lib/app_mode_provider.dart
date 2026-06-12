import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'onboarding_screen.dart';

final appModeProvider = StateProvider<AppMode>((ref) {
  final box = Hive.box('app_settings');
  final index = box.get('app_mode', defaultValue: AppMode.budget.index);
  return AppMode.values[index];
});
