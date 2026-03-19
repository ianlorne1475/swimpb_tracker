import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/event.dart';

void main() {
  group('SwimEvent Model Tests', () {
    final testEvent = SwimEvent(
      id: 100,
      meetId: 10,
      swimmerId: 1,
      distance: 50,
      stroke: 'Butterfly',
      timeMs: 28450, // 28.45
      date: '2024-03-19T00:00:00.000',
    );

    test('should format time correctly without minutes', () {
      expect(testEvent.formattedTime, '28.45');
    });

    test('should format time correctly with minutes', () {
      final longEvent = SwimEvent(
        meetId: 10,
        swimmerId: 1,
        distance: 400,
        stroke: 'Freestyle',
        timeMs: 255670, // 4:15.67
      );
      expect(longEvent.formattedTime, '4:15.67');
    });

    test('should format date correctly', () {
      expect(testEvent.formattedDate, '19/03/2024');
    });

    test('parseTimeToMs should handle MM:SS.hh format', () {
      expect(SwimEvent.parseTimeToMs('1:02.50'), 62500);
    });

    test('parseTimeToMs should handle SS.hh format', () {
      expect(SwimEvent.parseTimeToMs('31.20'), 31200);
    });

    test('parseTimeToMs should handle invalid format gracefully', () {
      expect(SwimEvent.parseTimeToMs('invalid'), 0);
    });

    test('should convert toMap correctly', () {
      final map = testEvent.toMap();
      expect(map['id'], 100);
      expect(map['timeMs'], 28450);
      expect(map['distance'], 50);
    });

    test('should create fromMap correctly with joins', () {
      final map = {
        'id': 101,
        'meetId': 10,
        'swimmerId': 1,
        'distance': 100,
        'stroke': 'Backstroke',
        'timeMs': 65400,
        'course': 'SCM',
        'date': '2024-01-01T00:00:00.000',
        'title': 'New Year Gala',
      };
      final event = SwimEvent.fromMap(map);
      expect(event.id, 101);
      expect(event.course, 'SCM');
      expect(event.meetTitle, 'New Year Gala');
    });
  });
}
