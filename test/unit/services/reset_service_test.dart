import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swimpb_tracker/services/preference_service.dart';
import 'package:swimpb_tracker/services/reset_service.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferenceService prefs;
  late ResetService resetService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferenceService();
    await prefs.init();
    resetService = ResetService();
  });

  test('should reset daily distance if date has changed', () async {
    // Setup: yesterday's reset date and some daily distance
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    
    await prefs.setLastResetDate(yesterdayStr);
    await prefs.setDailyDistance(1500);
    
    expect(prefs.getDailyDistance(), 1500);
    expect(prefs.getLastResetDate(), yesterdayStr);

    // Act: run reset check
    await resetService.checkAndResetDailyData();

    // Assert: distance should be 0, date should be today
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    expect(prefs.getDailyDistance(), 0);
    expect(prefs.getLastResetDate(), todayStr);
  });

  test('should NOT reset daily distance if date is the same', () async {
    // Setup: today's reset date and some daily distance
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    await prefs.setLastResetDate(todayStr);
    await prefs.setDailyDistance(1500);
    
    expect(prefs.getDailyDistance(), 1500);

    // Act: run reset check
    await resetService.checkAndResetDailyData();

    // Assert: distance should still be 1500
    expect(prefs.getDailyDistance(), 1500);
    expect(prefs.getLastResetDate(), todayStr);
  });
}
