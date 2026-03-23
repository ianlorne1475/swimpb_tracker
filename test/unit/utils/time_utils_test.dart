import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/utils/time_utils.dart';

void main() {
  group('TimeUtils - Formatting', () {
    test('formats sub-minute times (SS.hh)', () {
      expect(TimeUtils.formatTime(28500), '28.50');
      expect(TimeUtils.formatTime(990), '0.99');
    });

    test('formats multi-minute times (M:SS.hh)', () {
      expect(TimeUtils.formatTime(65000), '1:05.00');
      expect(TimeUtils.formatTime(125430), '2:05.43');
    });

    test('pads seconds and hundredths correctly', () {
      expect(TimeUtils.formatTime(61010), '1:01.01');
    });
  });

  group('TimeUtils - Parsing', () {
    test('parses SS.hh format', () {
      expect(TimeUtils.parseTimeToMs('28.50'), 28500);
      expect(TimeUtils.parseTimeToMs(' 0.99 '), 990);
    });

    test('parses M:SS.hh format', () {
      expect(TimeUtils.parseTimeToMs('1:05.00'), 65000);
      expect(TimeUtils.parseTimeToMs('2:05.43'), 125430);
      expect(TimeUtils.parseTimeToMs('1.05.00'), 65000); // Also handles dots instead of colons
    });

    test('handles malformed strings safely', () {
      expect(TimeUtils.parseTimeToMs('abc'), 0);
      expect(TimeUtils.parseTimeToMs(''), 0);
    });
  });
}
