import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swimpb_tracker/services/preference_service.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferenceService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferenceService();
    await prefs.init();
  });

  test('should persist theme mode', () async {
    expect(prefs.getThemeMode(), ThemeMode.system);
    
    await prefs.setThemeMode(ThemeMode.dark);
    expect(prefs.getThemeMode(), ThemeMode.dark);
    
    await prefs.setThemeMode(ThemeMode.light);
    expect(prefs.getThemeMode(), ThemeMode.light);
  });

  test('should persist daily distance', () async {
    expect(prefs.getDailyDistance(), 0);
    
    await prefs.setDailyDistance(1000);
    expect(prefs.getDailyDistance(), 1000);
    
    await prefs.resetDailyData();
    expect(prefs.getDailyDistance(), 0);
  });
}
