import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swimpb_tracker/database_helper.dart';
import 'package:swimpb_tracker/services/bulk_export_service.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  group('BulkExportService Tests', () {
    late BulkExportService exportService;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      exportService = BulkExportService(dbHelper: mockDb);
    });

    test('getSwimmerCsvContent should include Gender column and data', () async {
      final mockEvents = [
        {
          'firstName': 'John',
          'surname': 'Doe',
          'gender': 'Male',
          'dob': '2010-01-01',
          'nationality': 'SG',
          'meetTitle': 'Meet 1',
          'meetDate': '2023-01-01',
          'course': 'LCM',
          'distance': 50,
          'stroke': 'Freestyle',
          'timeMs': 30000,
          'club': 'Club 1',
          'dataType': 'Result',
          'photoPath': null,
        }
      ];

      when(() => mockDb.getEventsForExport(any())).thenAnswer((_) async => mockEvents);
      when(() => mockDb.getGoalsForExport(any())).thenAnswer((_) async => []);

      final csv = await exportService.getSwimmerCsvContent(1);
      final lines = csv.split('\n');
      
      // Check header
      expect(lines[0], contains('Gender'));
      
      // Check data row
      expect(lines[1], contains('Male'));
    });
  });
}
