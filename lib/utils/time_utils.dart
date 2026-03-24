import 'package:flutter/services.dart';

class TimeUtils {
  /// Formats time in milliseconds to a string: "M:SS.hh" or "SS.hh"
  static String formatTime(int timeMs) {
    final absMs = timeMs.abs();
    final duration = Duration(milliseconds: absMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hundredths = (absMs % 1000) ~/ 10;
    
    final sign = timeMs < 0 ? '-' : '';
    
    if (minutes > 0) {
      return '$sign$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
    } else {
      return '$sign$seconds.${hundredths.toString().padLeft(2, '0')}';
    }
  }

  /// Formats a time delta (e.g. "+1.20s" or "-0.50s")
  static String formatDelta(int deltaMs) {
    final isFaster = deltaMs <= 0;
    final absMs = deltaMs.abs();
    final seconds = absMs / 1000;
    return '${isFaster ? '-' : '+'}${seconds.toStringAsFixed(2)}s';
  }

  /// Parses a time string (MM:SS.hh or SS.hh) to milliseconds
  static int parseTimeToMs(String timeStr) {
    try {
      final clean = timeStr.trim().replaceAll(':', '.');
      final parts = clean.split('.');
      
      final filtered = parts.where((p) => p.isNotEmpty).toList();
      
      if (filtered.length >= 3) {
        // Handle MM.SS.hh
        final m = int.tryParse(filtered[filtered.length - 3]) ?? 0;
        final s = int.tryParse(filtered[filtered.length - 2]) ?? 0;
        final hStr = filtered[filtered.length - 1];
        final h = int.tryParse(hStr.padRight(2, '0').substring(0, 2)) ?? 0;
        return (m * 60000) + (s * 1000) + (h * 10);
      } else if (filtered.length == 2) {
        // SS.hh
        final s = int.tryParse(filtered[0]) ?? 0;
        final hStr = filtered[1];
        if (hStr.length >= 3 && (filtered[0] == '0' || filtered[0].isEmpty)) {
           return int.tryParse(hStr) ?? 0;
        }
        final h = int.tryParse(hStr.padRight(2, '0').substring(0, 2)) ?? 0;
        return (s * 1000) + (h * 10);
      } else if (filtered.length == 1) {
        return int.tryParse(filtered[0]) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Alias for formatTime to maintain compatibility
  static String formatDuration(int timeMs) => formatTime(timeMs);
}

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Only allow digits
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) digits = digits.substring(0, 6);

    String formatted = '';
    if (digits.length <= 2) {
      formatted = digits;
    } else if (digits.length <= 4) {
      // SS.hh
      final hh = digits.substring(digits.length - 2);
      final ss = digits.substring(0, digits.length - 2);
      formatted = '$ss.$hh';
    } else {
      // M:SS.hh
      final hh = digits.substring(digits.length - 2);
      final ss = digits.substring(digits.length - 4, digits.length - 2);
      final m = digits.substring(0, digits.length - 4);
      formatted = '$m:$ss.$hh';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
