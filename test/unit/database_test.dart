import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swimpb_tracker/database_helper.dart';
import 'package:swimpb_tracker/models/swimmer.dart';
import 'package:swimpb_tracker/models/meet.dart';
import 'package:swimpb_tracker/models/event.dart';

void main() {
  // Setup sqflite_common_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper CRUD Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      DatabaseHelper.testPath = inMemoryDatabasePath;
      await dbHelper.clearAllData();
    });

    test('should insert and retrieve swimmer', () async {
      final swimmer = Swimmer(
        firstName: 'Ian',
        surname: 'Hawkins',
        dob: DateTime(2010, 1, 1),
        nationality: 'GBR',
        gender: 'Male',
      );

      final id = await dbHelper.insertSwimmer(swimmer);
      expect(id, greaterThan(0));

      final swimmers = await dbHelper.getSwimmers();
      expect(swimmers.length, 1);
      expect(swimmers.first.firstName, 'Ian');
    });

    test('should update swimmer correctly', () async {
      final id = await dbHelper.insertSwimmer(Swimmer(
        firstName: 'Ian', surname: 'Hawkins', dob: DateTime(2010, 1, 1), nationality: 'GBR', gender: 'Male'
      ));

      final updatedSwimmer = Swimmer(
        id: id,
        firstName: 'Ian',
        surname: 'Hawkins',
        dob: DateTime(2010, 1, 1),
        nationality: 'GBR',
        gender: 'Male',
        club: 'Wimbledon SC',
      );

      await dbHelper.updateSwimmer(updatedSwimmer);
      final swimmers = await dbHelper.getSwimmers();
      expect(swimmers.first.club, 'Wimbledon SC');
    });

    test('should insert and retrieve meet and event', () async {
      final swimmerId = await dbHelper.insertSwimmer(Swimmer(
        firstName: 'Ian', surname: 'Hawkins', dob: DateTime(2010, 1, 1), nationality: 'GBR', gender: 'Male'
      ));

      final meetId = await dbHelper.insertMeet(SwimMeet(
        title: 'Regional Gala', date: DateTime(2024, 3, 19), course: 'SCM'
      ));

      final eventId = await dbHelper.insertEvent(SwimEvent(
        meetId: meetId, swimmerId: swimmerId, distance: 50, stroke: 'Butterfly', timeMs: 28500
      ));

      expect(eventId, greaterThan(0));

      final pbs = await dbHelper.getPBsBySwimmer(swimmerId);
      expect(pbs.length, 1);
      expect(pbs.first.timeMs, 28500);
      expect(pbs.first.meetTitle, 'Regional Gala');
    });

    test('should delete events by course correctly', () async {
      final swimmerId = await dbHelper.insertSwimmer(Swimmer(
        firstName: 'Ian', surname: 'Hawkins', dob: DateTime(2010, 1, 1), nationality: 'GBR', gender: 'Male'
      ));

      final meetIdScm = await dbHelper.insertMeet(SwimMeet(
        title: 'SCM Gala', date: DateTime(2024, 1, 1), course: 'SCM'
      ));
      final meetIdLcm = await dbHelper.insertMeet(SwimMeet(
        title: 'LCM Gala', date: DateTime(2024, 6, 1), course: 'LCM'
      ));

      await dbHelper.insertEvent(SwimEvent(
        meetId: meetIdScm, swimmerId: swimmerId, distance: 50, stroke: 'Fly', timeMs: 30000
      ));
      await dbHelper.insertEvent(SwimEvent(
        meetId: meetIdLcm, swimmerId: swimmerId, distance: 50, stroke: 'Fly', timeMs: 31000
      ));

      await dbHelper.deleteEventsBySwimmerAndCourse(swimmerId, 'SCM');
      
      final scmCount = await dbHelper.getScmMeetCountBySwimmer(swimmerId);
      final lcmCount = await dbHelper.getLcmMeetCountBySwimmer(swimmerId);
      
      expect(scmCount, 0);
      expect(lcmCount, 1);
    });
  });
}
