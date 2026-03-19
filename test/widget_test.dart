import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SwimPBTrackerApp());

    // Verify that the title is present.
    expect(find.text('SwimPB Tracker'), findsWidgets);
  });
}
