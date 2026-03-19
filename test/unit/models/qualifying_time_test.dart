import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/qualifying_time.dart';

void main() {
  group('QualifyingTime Model Tests', () {
    final testQT = QualifyingTime(
      id: 500,
      standardName: 'SNAG 2026',
      gender: 'Male',
      ageMin: 14,
      ageMax: 14,
      distance: 100,
      stroke: 'Freestyle',
      course: 'SCM',
      timeMs: 58500, // 58.50
    );

    test('should convert toMap correctly', () {
      final map = testQT.toMap();
      expect(map['id'], 500);
      expect(map['standardName'], 'SNAG 2026');
      expect(map['ageMin'], 14);
      expect(map['timeMs'], 58500);
    });

    test('should create fromMap correctly', () {
      final map = {
        'id': 501,
        'standardName': 'County 2024',
        'gender': 'Female',
        'ageMin': 12,
        'ageMax': 13,
        'distance:': 50, // Typo in local variable name below, corrected
        'distance': 50,
        'stroke': 'Breaststroke',
        'course': 'LCM',
        'timeMs': 42100,
      };
      final qt = QualifyingTime.fromMap(map);
      expect(qt.id, 501);
      expect(qt.gender, 'Female');
      expect(qt.standardName, 'County 2024');
    });
  });
}
