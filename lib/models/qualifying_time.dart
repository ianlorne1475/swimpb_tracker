class QualifyingTime {
  final int? id;
  final String standardName; // e.g., "SNAG 2026"
  final String gender; // "Female" or "Male"
  final int ageMin;
  final int ageMax;
  final int distance;
  final String stroke;
  final String course; // "LCM" or "SCM"
  final int timeMs;

  QualifyingTime({
    this.id,
    required this.standardName,
    required this.gender,
    required this.ageMin,
    required this.ageMax,
    required this.distance,
    required this.stroke,
    required this.course,
    required this.timeMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'standardName': standardName,
      'gender': gender,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'distance': distance,
      'stroke': stroke,
      'course': course,
      'timeMs': timeMs,
    };
  }

  factory QualifyingTime.fromMap(Map<String, dynamic> map) {
    return QualifyingTime(
      id: map['id'],
      standardName: map['standardName'],
      gender: map['gender'],
      ageMin: map['ageMin'],
      ageMax: map['ageMax'],
      distance: map['distance'],
      stroke: map['stroke'],
      course: map['course'],
      timeMs: map['timeMs'],
    );
  }
}
