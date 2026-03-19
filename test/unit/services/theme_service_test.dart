import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/services/theme_service.dart';

void main() {
  group('ThemeService Tests', () {
    late ThemeService themeService;

    setUp(() {
      themeService = ThemeService();
      // Reset to default
      themeService.themeMode.value = ThemeMode.dark;
    });

    test('should start with dark mode by default', () {
      expect(themeService.themeMode.value, ThemeMode.dark);
      expect(themeService.isDarkMode, isTrue);
    });

    test('toggleTheme should switch between light and dark', () {
      themeService.toggleTheme();
      expect(themeService.themeMode.value, ThemeMode.light);
      expect(themeService.isDarkMode, isFalse);

      themeService.toggleTheme();
      expect(themeService.themeMode.value, ThemeMode.dark);
      expect(themeService.isDarkMode, isTrue);
    });
  });
}
