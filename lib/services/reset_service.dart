import 'package:intl/intl.dart';
import 'preference_service.dart';

class ResetService {
  static final ResetService _instance = ResetService._internal();
  factory ResetService() => _instance;
  ResetService._internal();

  final PreferenceService _prefs = PreferenceService();

  Future<void> checkAndResetDailyData() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final lastReset = _prefs.getLastResetDate();

    if (lastReset != today) {
      print('Daily reset triggered: $lastReset -> $today');
      // Add any specific daily reset logic here
      await _prefs.setLastResetDate(today);
    }
  }

  // Helper for testing
  Future<void> forceResetForTesting(DateTime simulatedDate) async {
    final date = DateFormat('yyyy-MM-dd').format(simulatedDate);
    await _prefs.setLastResetDate(date);
  }
}
