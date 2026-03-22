import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:swimpb_tracker/database_helper.dart';
import 'package:swimpb_tracker/models/event.dart';
import 'package:swimpb_tracker/models/meet.dart';
import 'package:swimpb_tracker/models/swimmer.dart';
import 'package:swimpb_tracker/models/goal.dart';
import 'package:swimpb_tracker/services/bulk_import_service.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    // For testing, we just execute the action. 
    // We don't need a real Transaction object unless the tests specifically check it.
    // However, mocktail might complain if we pass a null txn.
    return await action(MockTransaction());
  }
}

class MockTransaction extends Mock implements Transaction {}

void main() {
  group('BulkImportService Tests', () {
    late BulkImportService importService;
    late MockDatabaseHelper mockDb;

    setUpAll(() {
      registerFallbackValue(Swimmer(firstName: '', surname: '', dob: DateTime.now(), nationality: '', gender: ''));
      registerFallbackValue(SwimMeet(title: '', date: DateTime.now(), course: ''));
      registerFallbackValue(SwimEvent(meetId: 0, swimmerId: 0, distance: 0, stroke: '', timeMs: 0));
      registerFallbackValue(SwimmerGoal(swimmerId: 0, distance: 0, stroke: '', timeMs: 0, course: ''));
    });

    setUp(() {
      mockDb = MockDatabaseHelper();
      importService = BulkImportService(dbHelper: mockDb);
    });

    test('should import from JSON correctly', () async {
      final jsonString = '''
      {
        "swimmers": [
          {
            "firstName": "Ian",
            "surname": "Hawkins",
            "dob": "2010-01-01T00:00:00.000",
            "nationality": "GBR",
            "meets": [
              {
                "title": "Gala",
                "date": "2024-01-01T00:00:00.000",
                "course": "SCM",
                "events": [
                  { "distance": 50, "stroke": "Fly", "timeMs": 30000 }
                ]
              }
            ]
          }
        ]
      }
      ''';

      when(() => mockDb.getOrCreateSwimmer(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 1);
      when(() => mockDb.getOrCreateMeet(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 10);
      when(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 100);
      when(() => mockDb.insertGoal(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 200);

      final result = await importService.importFromJson(jsonString);
      expect(result, 1);
      verify(() => mockDb.getOrCreateSwimmer(any(), executor: any(named: 'executor'))).called(1);
      verify(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).called(1);
    });

    test('should import from standard CSV correctly', () async {
      final csvString = 'FirstName,Surname,DOB,Nationality,MeetTitle,MeetDate,Course,Distance,Stroke,TimeMs\n'
          'Ian,Hawkins,2010-01-01,GBR,Gala,2024-03-19,SCM,50,Butterfly,28500';

      when(() => mockDb.getOrCreateSwimmer(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 1);
      when(() => mockDb.getOrCreateMeet(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 10);
      when(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 100);

      final result = await importService.importFromCsv(csvString);
      expect(result, 1);
      verify(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).called(1);
    });

    test('should handle matrix CSV format', () async {
      // Very abbreviated matrix for testing
      final csvString = 'Date,2024-03-19\n'
          'Meet Name,Regionals\n'
          '50m\n'
          'Butterfly,28.50';

      when(() => mockDb.getOrCreateMeet(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 10);
      when(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).thenAnswer((_) async => 100);

      // Matrix requires targetSwimmerId
      final result = await importService.importFromCsv(csvString, targetSwimmerId: 1);
      expect(result, 1);
      verify(() => mockDb.insertEvent(any(), executor: any(named: 'executor'))).called(1);
    });
  });
}
