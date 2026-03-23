class SwimMeet {
  final int? id;
  final String title;
  final DateTime date;
  final String? club; // Optional, can be populated via joins for a specific swimmer

  SwimMeet({
    this.id,
    required this.title,
    required this.date,
    required this.course,
    this.club,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'course': course,
    };
  }

  factory SwimMeet.fromMap(Map<String, dynamic> map) {
    return SwimMeet(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      course: map['course'],
      club: map['club'],
    );
  }
}
