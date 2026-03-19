import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/swimmer.dart';

void main() {
  group('Swimmer Model Tests', () {
    final testSwimmer = Swimmer(
      id: 1,
      firstName: 'Ian',
      surname: 'Hawkins',
      dob: DateTime(2010, 5, 15),
      nationality: 'GBR',
      gender: 'Male',
      club: 'Wimbledon',
    );

    test('should return correct fullName', () {
      expect(testSwimmer.fullName, 'Ian Hawkins');
    });

    test('should calculate correct age at year end', () {
      final currentYear = DateTime.now().year;
      final expectedAge = currentYear - 2010;
      expect(testSwimmer.calculateAgeAtEndYear(), expectedAge);
    });

    test('should convert toMap correctly', () {
      final map = testSwimmer.toMap();
      expect(map['id'], 1);
      expect(map['firstName'], 'Ian');
      expect(map['dob'], testSwimmer.dob.toIso8601String());
      expect(map['gender'], 'Male');
    });

    test('should create fromMap correctly', () {
      final map = {
        'id': 2,
        'firstName': 'Sarah',
        'surname': 'Jones',
        'dob': '2012-08-20T00:00:00.000',
        'nationality': 'USA',
        'gender': 'Female',
        'club': 'London SC',
      };
      final swimmer = Swimmer.fromMap(map);
      expect(swimmer.id, 2);
      expect(swimmer.firstName, 'Sarah');
      expect(swimmer.dob, DateTime(2012, 8, 20));
      expect(swimmer.gender, 'Female');
    });

    test('should handle missing gender in fromMap with default', () {
      final map = {
        'id': 3,
        'firstName': 'Alex',
        'surname': 'Smith',
        'dob': '2015-01-01T00:00:00.000',
        'nationality': 'AUS',
      };
      final swimmer = Swimmer.fromMap(map);
      expect(swimmer.gender, 'Female'); // Default value in fromMap
    });
  });
}
