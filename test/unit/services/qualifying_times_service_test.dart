import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swimpb_tracker/database_helper.dart';
import 'package:swimpb_tracker/models/qualifying_time.dart';
import 'package:swimpb_tracker/services/qualifying_times_service.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  group('QualifyingTimesService Tests', () {
    late QualifyingTimesService qtService;
    late MockDatabaseHelper mockDb;

    setUpAll(() {
      registerFallbackValue(QualifyingTime(standardName: '', stroke: '', distance: 0, timeMs: 0, course: '', ageMin: 0, ageMax: 0, gender: ''));
    });

    setUp(() {
      mockDb = MockDatabaseHelper();
      qtService = QualifyingTimesService(dbHelper: mockDb);
    });

    test('seedAllStandards should only seed if count is 0', () async {
      when(() => mockDb.getQualifyingTimesCount()).thenAnswer((_) async => 500);
      
      await qtService.seedAllStandards();
      
      verify(() => mockDb.getQualifyingTimesCount()).called(1);
      verifyNever(() => mockDb.insertQualifyingTime(any()));
    });

    test('seedAllStandards should seed if count is 0', () async {
      when(() => mockDb.getQualifyingTimesCount()).thenAnswer((_) async => 0);
      when(() => mockDb.insertQualifyingTime(any())).thenAnswer((_) async => 1);
      
      await qtService.seedAllStandards();
      
      verify(() => mockDb.getQualifyingTimesCount()).called(1);
      // Ensure many insertions were attempted
      verify(() => mockDb.insertQualifyingTime(any())).called(greaterThan(100));
    });
  });
}
