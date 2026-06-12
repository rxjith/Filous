import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum ThemeSource { dynamic, preset }

class AppThemeState {
  final ThemeMode themeMode;
  final ThemeSource themeSource;
  final Color presetColor;

  AppThemeState({
    required this.themeMode,
    required this.themeSource,
    required this.presetColor,
  });

  AppThemeState copyWith({
    ThemeMode? themeMode,
    ThemeSource? themeSource,
    Color? presetColor,
  }) {
    return AppThemeState(
      themeMode: themeMode ?? this.themeMode,
      themeSource: themeSource ?? this.themeSource,
      presetColor: presetColor ?? this.presetColor,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeState> {
  ThemeNotifier()
      : super(AppThemeState(
          themeMode: ThemeMode.system,
          themeSource: ThemeSource.dynamic,
          presetColor: const Color(0xFF6366F1),
        )) {
    _loadSettings();
  }

  late Box _settingsBox;

  Future<void> _loadSettings() async {
    _settingsBox = Hive.box('app_settings');
    final modeIndex = _settingsBox.get('theme_mode', defaultValue: ThemeMode.system.index);
    final sourceIndex = _settingsBox.get('theme_source', defaultValue: ThemeSource.dynamic.index);
    final colorValue = _settingsBox.get('preset_color', defaultValue: const Color(0xFF6366F1).value);

    state = AppThemeState(
      themeMode: ThemeMode.values[modeIndex],
      themeSource: ThemeSource.values[sourceIndex],
      presetColor: Color(colorValue),
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _settingsBox.put('theme_mode', mode.index);
  }

  void setThemeSource(ThemeSource source) {
    state = state.copyWith(themeSource: source);
    _settingsBox.put('theme_source', source.index);
  }

  void setPresetColor(Color color) {
    state = state.copyWith(presetColor: color, themeSource: ThemeSource.preset);
    _settingsBox.put('preset_color', color.value);
    _settingsBox.put('theme_source', ThemeSource.preset.index);
  }
}
