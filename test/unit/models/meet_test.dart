import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/meet.dart';

void main() {
  group('SwimMeet Model Tests', () {
    final testDate = DateTime(2024, 3, 19);
    final testMeet = SwimMeet(
      id: 10,
      title: 'Regional Championships',
      date: testDate,
      course: 'SCM',
    );

    test('should convert toMap correctly', () {
      final map = testMeet.toMap();
      expect(map['id'], 10);
      expect(map['title'], 'Regional Championships');
      expect(map['date'], testDate.toIso8601String());
      expect(map['course'], 'SCM');
    });

    test('should create fromMap correctly', () {
      final map = {
        'id': 11,
        'title': 'National Qualifiers',
        'date': '2024-05-10T00:00:00.000',
        'course': 'LCM',
      };
      final meet = SwimMeet.fromMap(map);
      expect(meet.id, 11);
      expect(meet.title, 'National Qualifiers');
      expect(meet.date, DateTime(2024, 5, 10));
      expect(meet.course, 'LCM');
    });
  });
}
