import '../utils/time_utils.dart';

class SwimEvent {
  final int? id;
  final int meetId;
  final int swimmerId;
  final int distance; // e.g., 50, 100, 200
  final String stroke; // e.g., 'Freestyle', 'Backstroke'
  final int timeMs; // time in milliseconds for easier sorting/graphing
  final String? course; // optional, for joined queries
  final String? date;   // optional, for joined queries
  final String? meetTitle; // optional, for joined queries

  final String? club; // club represented during this event

  SwimEvent({
    this.id,
    required this.meetId,
    required this.swimmerId,
    required this.distance,
    required this.stroke,
    required this.timeMs,
    this.course,
    this.date,
    this.meetTitle,
    this.club,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meetId': meetId,
      'swimmerId': swimmerId,
      'distance': distance,
      'stroke': stroke,
      'timeMs': timeMs,
      'club': club,
    };
  }

  factory SwimEvent.fromMap(Map<String, dynamic> map) {
    return SwimEvent(
      id: map['id'],
      meetId: map['meetId'],
      swimmerId: map['swimmerId'],
      distance: map['distance'],
      stroke: map['stroke'],
      timeMs: map['timeMs'],
      course: map['course'],
      date: map['date'],
      meetTitle: map['title'] ?? map['meetTitle'], // title comes from meets table join
      club: map['club'],
    );
  }


  String get formattedTime => TimeUtils.formatTime(timeMs);

  String get formattedDate {
    if (date == null) return '';
    try {
      final dateTime = DateTime.parse(date!);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date!;
    }
  }

  static int parseTimeToMs(String timeStr) => TimeUtils.parseTimeToMs(timeStr);
}
