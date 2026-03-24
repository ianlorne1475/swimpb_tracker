import '../utils/time_utils.dart';

class SwimmerGoal {
  final int? id;
  final int swimmerId;
  final int distance;
  final String stroke;
  final String course;
  final int timeMs;
  final DateTime? targetDate;

  SwimmerGoal({
    this.id,
    required this.swimmerId,
    required this.distance,
    required this.stroke,
    required this.course,
    required this.timeMs,
    this.targetDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'swimmerId': swimmerId,
      'distance': distance,
      'stroke': stroke,
      'course': course,
      'timeMs': timeMs,
      'targetDate': targetDate?.toIso8601String(),
    };
  }

  factory SwimmerGoal.fromMap(Map<String, dynamic> map) {
    return SwimmerGoal(
      id: map['id'],
      swimmerId: map['swimmerId'],
      distance: map['distance'],
      stroke: map['stroke'],
      course: map['course'],
      timeMs: map['timeMs'],
      targetDate: map['targetDate'] != null ? DateTime.parse(map['targetDate']) : null,
    );
  }

  String get formattedTime => TimeUtils.formatTime(timeMs);
}
