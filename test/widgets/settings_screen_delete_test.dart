import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/swimmer.dart';
import 'package:swimpb_tracker/screens/settings_screen.dart';

void main() {
  final swimmersSeed = [
    Swimmer(id: 1, firstName: 'Ian', surname: 'Hawkins', dob: DateTime(2010, 1, 1), nationality: 'GB', gender: 'Male', club: 'Wimbledon SC'),
    Swimmer(id: 2, firstName: 'Sarah', surname: 'Sjöström', dob: DateTime(1993, 8, 17), nationality: 'SE', gender: 'Female', club: 'Sweden'),
  ];

  Future<void> setupSettingsScreen(WidgetTester tester, {
    required ValueNotifier<List<Swimmer>> swimmersNotifier,
    required ValueNotifier<Set<int>> idsWithResultsNotifier,
    Function(Swimmer)? onDeleteSwimmer,
    Function(Swimmer?)? onDeleteRaceData,
    VoidCallback? onClearAllData,
    Function(Swimmer)? onReports,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: SettingsScreen(
        swimmersNotifier: swimmersNotifier,
        swimmerIdsWithResultsNotifier: idsWithResultsNotifier,
        onAddSwimmer: () {},
        onImportData: () {},
        onExportData: () {},
        onReports: onReports ?? (_) {},
        onDeleteRaceData: onDeleteRaceData ?? (_) {},
        onClearAllData: onClearAllData ?? () {},
        onDeleteSwimmer: onDeleteSwimmer ?? (_) {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Generate Reports shows swimmer selection dialog', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1}); // Only Ian has results
    Swimmer? reportedSwimmer;

    await setupSettingsScreen(
      tester,
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
      onReports: (s) => reportedSwimmer = s,
    );

    final reportTile = find.widgetWithText(ListTile, 'Generate Reports');
    await tester.scrollUntilVisible(reportTile, 500.0);
    await tester.tap(reportTile);
    await tester.pumpAndSettle();

    expect(find.text('Select Swimmer for Report'), findsOneWidget);
    
    // Tap dropdown
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();

    // Ian should be there, Sarah should NOT (no results)
    expect(find.text('Ian Hawkins'), findsAtLeastNWidgets(1));
    expect(find.text('Sarah Sjöström'), findsNothing);

    // Select Ian
    await tester.tap(find.text('Ian Hawkins').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(reportedSwimmer, equals(swimmersSeed[0]));
  });

  testWidgets('Clearing race data removes swimmer reactively', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1, 2});

    await setupSettingsScreen(
      tester, 
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
    );

    // 1. Open "Delete Race Data"
    final raceTile = find.widgetWithText(ListTile, 'Delete Race Data');
    await tester.scrollUntilVisible(raceTile, 500.0);
    await tester.tap(raceTile);
    await tester.pumpAndSettle();

    // Verify both are present
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();
    expect(find.text('Ian Hawkins'), findsAtLeastNWidgets(1));
    expect(find.text('Sarah Sjöström'), findsAtLeastNWidgets(1));
    
    // Close dropdown
    await tester.tapAt(const Offset(10, 10)); 
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Clear Ian's results (simulate callback effect)
    idsWithResultsNotifier.value = {2};
    await tester.pumpAndSettle();

    // 3. Open "Delete Race Data" again
    await tester.tap(raceTile);
    await tester.pumpAndSettle();

    // 4. Verify dropdown only contains Sarah
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();

    expect(find.text('Ian Hawkins'), findsNothing);
    expect(find.text('Sarah Sjöström'), findsAtLeastNWidgets(1));
  });

  testWidgets('Deleting a swimmer removes them reactively', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1, 2});

    await setupSettingsScreen(
      tester,
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
    );

    // 1. Simulate deleting Ian
    swimmersNotifier.value = [swimmersSeed[1]];
    await tester.pumpAndSettle();

    // 2. Open "Delete Swimmer"
    final deleteTile = find.widgetWithText(ListTile, 'Delete Swimmer');
    await tester.scrollUntilVisible(deleteTile, 500.0);
    await tester.tap(deleteTile);
    await tester.pumpAndSettle();

    // 3. Verify dropdown only contains Sarah
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();

    expect(find.text('Ian Hawkins'), findsNothing);
    expect(find.text('Sarah Sjöström'), findsAtLeastNWidgets(1));
  });

  testWidgets('Delete Swimmer shows danger dialog with selection', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1, 2});
    Swimmer? deletedSwimmer;

    await setupSettingsScreen(
      tester,
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
      onDeleteSwimmer: (s) => deletedSwimmer = s,
    );

    final deleteTile = find.widgetWithText(ListTile, 'Delete Swimmer');
    await tester.scrollUntilVisible(deleteTile, 500.0);
    await tester.tap(deleteTile);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete Swimmer Profile')), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ian Hawkins').last);
    await tester.pumpAndSettle();

    expect(find.text('Warning: All records for Ian will be lost.'), findsOneWidget);

    await tester.tap(find.text('Delete Permanently'));
    await tester.pumpAndSettle();

    expect(deletedSwimmer, equals(swimmersSeed[0]));
  });

  testWidgets('Delete Race Data shows danger dialog with selection', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1, 2});
    bool deleteRaceCalled = false;

    await setupSettingsScreen(
      tester,
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
      onDeleteRaceData: (_) => deleteRaceCalled = true,
    );

    final tile = find.widgetWithText(ListTile, 'Delete Race Data');
    await tester.scrollUntilVisible(tile, 500.0);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete Race Data')), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<Swimmer>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarah Sjöström').last);
    await tester.pumpAndSettle();

    expect(find.text('Warning: All records for Sarah will be lost.'), findsOneWidget);

    await tester.tap(find.text('Clear All Results'));
    await tester.pumpAndSettle();

    expect(deleteRaceCalled, isTrue);
  });

  testWidgets('Clear All Data shows danger dialog without selection', (WidgetTester tester) async {
    final swimmersNotifier = ValueNotifier<List<Swimmer>>(swimmersSeed);
    final idsWithResultsNotifier = ValueNotifier<Set<int>>({1, 2});
    bool clearAllCalled = false;

    await setupSettingsScreen(
      tester,
      swimmersNotifier: swimmersNotifier,
      idsWithResultsNotifier: idsWithResultsNotifier,
      onClearAllData: () => clearAllCalled = true,
    );

    final tile = find.widgetWithText(ListTile, 'Clear All Data');
    await tester.scrollUntilVisible(tile, 500.0);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Clear All Data')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<Swimmer>), findsNothing);
    expect(find.textContaining('Warning: This will PERMANENTLY delete ALL swimmers'), findsOneWidget);

    await tester.tap(find.text('Clear Everything'));
    await tester.pumpAndSettle();

    expect(clearAllCalled, isTrue);
  });
}
