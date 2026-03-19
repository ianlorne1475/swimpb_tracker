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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meetId': meetId,
      'swimmerId': swimmerId,
      'distance': distance,
      'stroke': stroke,
      'timeMs': timeMs,
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

  String get formattedDate {
    if (date == null) return '';
    try {
      final dateTime = DateTime.parse(date!);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date!;
    }
  }

  static int parseTimeToMs(String timeStr) {
    // Expected formats: "MM:SS.hh" or "SS.hh"
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final hundredths = int.parse(secondsParts[1]);
        return (minutes * 60 * 1000) + (seconds * 1000) + (hundredths * 10);
      } else {
        final parts = timeStr.split('.');
        final seconds = int.parse(parts[0]);
        final hundredths = int.parse(parts[1]);
        return (seconds * 1000) + (hundredths * 10);
      }
    } catch (e) {
      print('DEBUG: parseTimeToMs error for "$timeStr": $e');
      return 0;
    }
  }
}
