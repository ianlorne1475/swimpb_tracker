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
    try {
      final clean = timeStr.trim().replaceAll(':', '.');
      final parts = clean.split('.');
      
      if (parts.length >= 3) {
        // Handle MM.SS.hh or HH.MM.SS.hh (unlikely)
        final m = int.parse(parts[parts.length - 3]);
        final s = int.parse(parts[parts.length - 2]);
        final hStr = parts[parts.length - 1];
        final h = int.parse(hStr.padRight(2, '0').substring(0, 2));
        return (m * 60000) + (s * 1000) + (h * 10);
      } else if (parts.length == 2) {
        // SS.hh
        final s = int.parse(parts[0]);
        final hStr = parts[1];
        // Special case: if hStr is very long, it might be raw milliseconds?
        if (hStr.length >= 3 && parts[0] == '0' || parts[0].isEmpty) {
           return int.tryParse(hStr) ?? 0;
        }
        final h = int.parse(hStr.padRight(2, '0').substring(0, 2));
        return (s * 1000) + (h * 10);
      } else if (parts.length == 1) {
        return int.tryParse(parts[0]) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
