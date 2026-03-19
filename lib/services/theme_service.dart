import 'package:flutter/material.dart';
import '../services/preference_service.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(PreferenceService().getThemeMode());

  void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    PreferenceService().setThemeMode(themeMode.value);
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
}
