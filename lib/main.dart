import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/preference_service.dart';
import 'services/reset_service.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Initialize persistence
  final prefs = PreferenceService();
  await prefs.init();
  
  // Check for daily resets
  await ResetService().checkAndResetDailyData();
  
  runApp(const SwimPBTrackerApp());
}

class SwimPBTrackerApp extends StatelessWidget {
  const SwimPBTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'SwimPB Tracker',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
