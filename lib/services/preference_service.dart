import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  factory PreferenceService() => _instance;
  PreferenceService._internal();

  static SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Theme
  ThemeMode getThemeMode() {
    final theme = _prefs?.getString('theme_mode');
    if (theme == 'light') return ThemeMode.light;
    if (theme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString('theme_mode', mode.toString().split('.').last);
  }

  // Reset Logic
  String? getLastResetDate() {
    return _prefs?.getString('last_reset_date');
  }

  Future<void> setLastResetDate(String date) async {
    await _prefs?.setString('last_reset_date', date);
  }
}
