class SwimmerGoal {
  final int? id;
  final int swimmerId;
  final int distance;
  final String stroke;
  final String course;
  final int timeMs;

  SwimmerGoal({
    this.id,
    required this.swimmerId,
    required this.distance,
    required this.stroke,
    required this.course,
    required this.timeMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'swimmerId': swimmerId,
      'distance': distance,
      'stroke': stroke,
      'course': course,
      'timeMs': timeMs,
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
    );
  }

  String get formattedTime {
    final duration = Duration(milliseconds: timeMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hundredths = (timeMs % 1000) ~/ 10;
    
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
    } else {
      return '$seconds.${hundredths.toString().padLeft(2, '0')}';
    }
  }
}
