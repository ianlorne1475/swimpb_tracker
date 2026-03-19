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
    
    expect(prefs.getLastResetDate(), yesterdayStr);

    // Act: run reset check
    await resetService.checkAndResetDailyData();

    // Assert: date should be today
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    expect(prefs.getLastResetDate(), todayStr);
  });

  test('should NOT update reset date if date is the same', () async {
    // Setup: today's reset date
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    await prefs.setLastResetDate(todayStr);
    
    expect(prefs.getLastResetDate(), todayStr);

    // Act: run reset check
    await resetService.checkAndResetDailyData();

    // Assert: date should still be today
    expect(prefs.getLastResetDate(), todayStr);
  });
}
