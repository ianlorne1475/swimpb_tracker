class TimeUtils {
  /// Formats time in milliseconds to a string: "M:SS.hh" or "SS.hh"
  static String formatTime(int timeMs) {
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

  /// Parses a time string (MM:SS.hh or SS.hh) to milliseconds
  static int parseTimeToMs(String timeStr) {
    try {
      final clean = timeStr.trim().replaceAll(':', '.');
      final parts = clean.split('.');
      
      if (parts.length >= 3) {
        // Handle MM.SS.hh
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
        if (hStr.length >= 3 && (parts[0] == '0' || parts[0].isEmpty)) {
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

  /// Alias for formatTime to maintain compatibility
  static String formatDuration(int timeMs) => formatTime(timeMs);
}
