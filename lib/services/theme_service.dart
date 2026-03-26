import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/preference_service.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// Initializes the theme from preferences
  void init() {
    themeMode.value = PreferenceService().getThemeMode();
  }

  void toggleTheme() {
    if (themeMode.value == ThemeMode.system) {
      // If we are in system mode, the first toggle should switch to the OPPOSITE of current appearance
      final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      themeMode.value = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else {
      themeMode.value = themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
    PreferenceService().setThemeMode(themeMode.value);
  }

  bool get isDarkMode {
    if (themeMode.value == ThemeMode.system) {
      // In system mode, check the actual platform dispatcher's brightness
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }
}
