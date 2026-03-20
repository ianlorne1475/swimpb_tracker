import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../database_helper.dart';
import '../models/swimmer.dart';
import '../models/meet.dart';
import '../models/event.dart';

class BulkImportService {
  final DatabaseHelper _dbHelper;
  final _textRecognizer = TextRecognizer();

  BulkImportService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper();

  void dispose() {
    _textRecognizer.close();
  }

  Future<int> importFromFile(File file, {int? targetSwimmerId, String? course}) async {
    final extension = file.path.split('.').last.toLowerCase();
    
    if (extension == 'xlsx') {
      final bytes = await file.readAsBytes();
      return await importFromXlsx(bytes, targetSwimmerId: targetSwimmerId, course: course);
    }

    if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
       // OCR handled externally via MainScreen
       return 0; 
    }
    
    final content = await file.readAsString();
    if (extension == 'json') {
      return await importFromJson(content);
    } else if (extension == 'csv') {
      return await importFromCsv(content, targetSwimmerId: targetSwimmerId, course: course);
    } else {
      throw Exception('Unsupported file format: $extension');
    }
  }

  Future<int> importFromXlsx(Uint8List bytes, {int? targetSwimmerId, String? course}) async {
    final excel = Excel.decodeBytes(bytes);
    int totalImported = 0;
    
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      final List<List<dynamic>> rows = sheet.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
      totalImported += await _importFromRows(rows, targetSwimmerId: targetSwimmerId, course: course);
    }
    return totalImported;
  }

  Future<int> importFromJson(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    int importedCount = 0;
    
    if (data.containsKey('swimmers')) {
      for (var swimmerData in data['swimmers']) {
        importedCount += await _importSwimmer(swimmerData);
      }
    }
    return importedCount;
  }

  Future<int> importFromCsv(String csvString, {int? targetSwimmerId, String? course}) async {
    if (csvString.isEmpty) return 0;

    // Detect delimiter
    String delimiter = ',';
    final lines = csvString.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      if (firstLine.split(';').length > firstLine.split(',').length) {
        delimiter = ';';
      } else if (firstLine.split('\t').length > firstLine.split(',').length) {
        delimiter = '\t';
      }
    }

    final List<List<dynamic>> rows = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: csvString.contains('\r\n') ? '\r\n' : '\n',
    ).convert(csvString);
    
    return await _importFromRows(rows, targetSwimmerId: targetSwimmerId, course: course);
  }

  Future<int> importReviewedResults(int swimmerId, String defaultMeetTitle, DateTime defaultMeetDate, String course, List<Map<String, dynamic>> results) async {
    int importedCount = 0;
    final Map<String, int> meetIdCache = {};

    for (var res in results) {
      try {
        final title = res['meetTitle'] ?? defaultMeetTitle;
        final dateStr = res['meetDate']?.toString() ?? '';
        DateTime date = defaultMeetDate;
        if (dateStr.isNotEmpty) {
           date = _parseFlexibleDate(dateStr) ?? defaultMeetDate;
        }

        final cacheKey = '$title|${date.toIso8601String()}|$course';
        int meetId;
        if (meetIdCache.containsKey(cacheKey)) {
          meetId = meetIdCache[cacheKey]!;
        } else {
          meetId = await _dbHelper.getOrCreateMeet(
            SwimMeet(title: title, date: date, course: course),
          );
          meetIdCache[cacheKey] = meetId;
        }

        final event = SwimEvent(
          meetId: meetId,
          swimmerId: swimmerId,
          distance: res['distance'],
          stroke: res['stroke'],
          timeMs: SwimEvent.parseTimeToMs(res['time']),
        );
        await _dbHelper.insertEvent(event);
        importedCount++;
      } catch (e) {
        // Skip malformed result
      }
    }
    return importedCount;
  }

  DateTime? _parseFlexibleDate(String dateStr) {
    try {
      final s = dateStr.trim().replaceAll('-', ' ').replaceAll('/', ' ').replaceAll('.', ' ');
      final parts = s.split(' ').where((p) => p.isNotEmpty).toList();
      
      if (parts.length == 3) {
        int day = int.tryParse(parts[0]) ?? 1;
        int year = int.tryParse(parts[2]) ?? DateTime.now().year;
        if (year < 100) year += 2000;

        int month = 1;
        final monthPart = parts[1].toLowerCase();
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final monthIdx = months.indexWhere((m) => monthPart.startsWith(m));
        if (monthIdx != -1) {
          month = monthIdx + 1;
        } else {
          month = int.tryParse(parts[1]) ?? 1;
        }
        return DateTime(year, month, day);
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> extractResultsFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    // First, try Matrix OCR (Table based)
    final grid = _reconstructGrid(recognizedText);
    if (_isMatrixGrid(grid)) {
      return _extractFromMatrixGrid(grid);
    }
    
    // Try Standard Grid (Row per result)
    if (_isStandardGrid(grid)) {
      return _extractFromStandardGrid(grid);
    }
    
    // Fallback to line-by-line
    return _parseResultsFromText(recognizedText.text);
  }

  bool _isMatrixGrid(List<List<String>> grid) {
    if (grid.length < 2) return false;
    // Check if we have 'Date' or 'Meet Name' headers as the first column
    for (var row in grid) {
      if (row.isNotEmpty) {
        final first = row[0].toLowerCase();
        if (first.contains('date') || first.contains('meet')) return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _extractFromMatrixGrid(List<List<String>> grid) {
    final List<Map<String, dynamic>> extracted = [];
    
    // Find header rows
    int dateRowIdx = -1;
    int meetRowIdx = -1;
    for (int i = 0; i < grid.length && i < 10; i++) {
      if (grid[i].isEmpty) continue;
      final first = grid[i][0].toLowerCase();
      if (first.contains('date')) dateRowIdx = i;
      if (first.contains('meet')) meetRowIdx = i;
    }

    if (dateRowIdx == -1 || meetRowIdx == -1) return [];

    final dateRow = grid[dateRowIdx];
    final meetRow = grid[meetRowIdx];
    int currentDistance = 50;

    for (int i = meetRowIdx + 1; i < grid.length; i++) {
      final row = grid[i];
      if (row.isEmpty) continue;

      final firstCell = row[0].trim();
      if (firstCell.isEmpty) continue;

      // Distance update
      if (firstCell.toLowerCase().contains(RegExp(r'(50|100|200|400|800|1500)\s*m?', caseSensitive: false))) {
        final match = RegExp(r'(50|100|200|400|800|1500)').firstMatch(firstCell);
        if (match != null) currentDistance = int.parse(match.group(1)!);
        continue;
      }

      final stroke = _normalizeStroke(firstCell);
      if (['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'].contains(stroke)) {
        for (int j = 1; j < row.length; j++) {
          if (j >= dateRow.length || j >= meetRow.length) break;
          
          final timeStr = row[j].trim();
          if (RegExp(r'\b(\d{1,2}:)?\d{1,2}[\.\:]\d{2}\b').hasMatch(timeStr)) {
            extracted.add({
              'distance': currentDistance,
              'stroke': stroke,
              'time': timeStr,
              'meetTitle': meetRow[j],
              'meetDate': dateRow[j],
              'original': '$firstCell @ ${meetRow[j]}',
            });
          }
        }
      }
    }
    return extracted;
  }

  bool _isStandardGrid(List<List<String>> grid) {
    for (int i = 0; i < grid.length && i < 10; i++) {
      final row = grid[i].map((e) => e.toLowerCase().replaceAll(' ', '')).toList();
      if (row.contains('firstname') || row.contains('surname') || row.contains('timems')) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _extractFromStandardGrid(List<List<String>> grid) {
    if (grid.isEmpty) return [];

    // Find header row
    int headerRowIdx = -1;
    for (int i = 0; i < grid.length && i < 10; i++) {
      final row = grid[i].map((e) => e.toLowerCase().replaceAll(' ', '')).toList();
      if (row.contains('firstname') || row.contains('surname') || row.contains('timems')) {
        headerRowIdx = i;
        break;
      }
    }

    if (headerRowIdx == -1) return [];

    final headers = grid[headerRowIdx].map((e) => e.toLowerCase().replaceAll(' ', '')).toList();
    
    // Find column indices
    final firstNameIdx = headers.indexOf('firstname');
    final surnameIdx = headers.indexOf('surname');
    final meetTitleIdx = headers.indexOf('meettitle');
    final meetDateIdx = headers.indexOf('meetdate');
    final distanceIdx = headers.indexWhere((h) => h.contains('distance'));
    final strokeIdx = headers.indexWhere((h) => h.contains('stroke'));
    final timeMsIdx = headers.indexWhere((h) => h.contains('time'));
    final courseIdx = headers.indexWhere((h) => h.contains('course'));

    if (timeMsIdx == -1) return [];

    final List<Map<String, dynamic>> extracted = [];
    for (int i = headerRowIdx + 1; i < grid.length; i++) {
      final row = grid[i];
      if (row.length <= timeMsIdx) continue;

      try {
        final distanceStr = distanceIdx != -1 && row.length > distanceIdx ? row[distanceIdx] : '50';
        final distance = int.tryParse(RegExp(r'\d+').firstMatch(distanceStr)?.group(0) ?? '50') ?? 50;
        
        final strokeStr = strokeIdx != -1 && row.length > strokeIdx ? row[strokeIdx] : 'Freestyle';
        final stroke = _normalizeStroke(strokeStr);
        
        final courseStr = courseIdx != -1 && row.length > courseIdx ? row[courseIdx] : null;
        final resCourse = courseStr != null ? _normalizeCourse(courseStr) : null;

        final timeMsStr = row[timeMsIdx].trim();
        if (timeMsStr.isEmpty) continue;
        
        // Convert TimeMs to formatted time for consistency in the review dialog
        String formattedTime;
        if (RegExp(r'^\d+$').hasMatch(timeMsStr)) {
          final ms = int.parse(timeMsStr);
          final duration = Duration(milliseconds: ms);
          final mins = duration.inMinutes;
          final secs = duration.inSeconds % 60;
          final millis = (ms % 1000) ~/ 10;
          formattedTime = mins > 0 ? '$mins:${secs.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}' : '$secs.${millis.toString().padLeft(2, '0')}';
        } else {
          formattedTime = timeMsStr;
        }

        extracted.add({
          'distance': distance,
          'stroke': stroke,
          'time': formattedTime,
          'course': resCourse,
          'meetTitle': meetTitleIdx != -1 && row.length > meetTitleIdx ? row[meetTitleIdx] : null,
          'meetDate': meetDateIdx != -1 && row.length > meetDateIdx ? row[meetDateIdx] : null,
          'original': row.join(' '),
        });
      } catch (e) { /* skip */ }
    }
    return extracted;
  }

  List<List<String>> _reconstructGrid(RecognizedText recognizedText) {
    final List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // Group by Y into initial rows
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final List<List<TextLine>> tempRows = [];
    if (allLines.isNotEmpty) {
      List<TextLine> currentRow = [allLines.first];
      for (int i = 1; i < allLines.length; i++) {
        final line = allLines[i];
        final prevLine = currentRow.last;
        final tolerance = prevLine.boundingBox.height * 0.7;
        if ((line.boundingBox.top - prevLine.boundingBox.top).abs() < tolerance) {
          currentRow.add(line);
        } else {
          tempRows.add(currentRow);
          currentRow = [line];
        }
      }
      tempRows.add(currentRow);
    }

    // Identify header row to define column anchors
    int headerRowIdx = -1;
    for (int i = 0; i < tempRows.length && i < 10; i++) {
      final rowText = tempRows[i].map((l) => l.text.toLowerCase()).toList();
      if (rowText.any((t) => t.contains('date') || t.contains('meet') || t.contains('first'))) {
        headerRowIdx = i;
        break;
      }
    }

    if (headerRowIdx == -1) {
      // Fallback: simple X-sort
      return tempRows.map((r) {
        r.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        return r.map((l) => l.text).toList();
      }).toList();
    }

    final headerRow = tempRows[headerRowIdx];
    headerRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    final List<double> colCenters = headerRow.map((l) => l.boundingBox.center.dx).toList();

    // Reconstruct grid by mapping each line to the nearest column anchor
    final resultGrid = <List<String>>[];
    for (var row in tempRows) {
      final gridRow = List.filled(colCenters.length, '');
      for (var line in row) {
        int bestCol = 0;
        double minDist = double.infinity;
        for (int c = 0; c < colCenters.length; c++) {
          final dist = (line.boundingBox.center.dx - colCenters[c]).abs();
          if (dist < minDist) {
            minDist = dist;
            bestCol = c;
          }
        }
        gridRow[bestCol] = gridRow[bestCol].isEmpty ? line.text : '${gridRow[bestCol]} ${line.text}';
      }
      resultGrid.add(gridRow);
    }
    return resultGrid;
  }

  List<Map<String, dynamic>> _parseResultsFromText(String text) {
    final List<Map<String, dynamic>> extracted = [];
    final lines = text.split('\n');

    for (var line in lines) {
      final cleanedLine = line.trim();
      if (cleanedLine.isEmpty) continue;

      // Distance Heuristic: look for 50, 100, 200, 400, 800, 1500 (with optional 'm')
      final distanceMatch = RegExp(r'\b(50|100|200|400|800|1500)\s*m?\b', caseSensitive: false).firstMatch(cleanedLine);
      
      // Stroke Heuristic: Free, Back, Breast, Fly, IM (including abbreviations)
      final strokeMatch = RegExp(r'\b(Freestyle|Free|Fr|Backstroke|Back|Bk|Breaststroke|Breast|Br|Butterfly|Fly|Fl|IM|Medley|Individual Medley)\b', caseSensitive: false).firstMatch(cleanedLine);
      
      // Time Heuristic: 28.45, 1:02.13, 10:23.45
      final timeMatch = RegExp(r'\b(\d{1,2}:)?\d{1,2}[\.\:]\d{2}\b').firstMatch(cleanedLine);

      if (distanceMatch != null && strokeMatch != null && timeMatch != null) {
        extracted.add({
          'distance': int.parse(distanceMatch.group(1)!),
          'stroke': _normalizeStroke(strokeMatch.group(1)!),
          'time': timeMatch.group(0)!,
          'original': cleanedLine,
        });
      }
    }
    return extracted;
  }

  Future<int> _importFromRows(List<List<dynamic>> rows, {int? targetSwimmerId, String? course}) async {
    if (rows.isEmpty) return 0;

    // Detect Matrix format
    bool isMatrix = false;
    for (int i = 0; i < rows.length && i < 5; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString().trim().toLowerCase() == 'date') {
        isMatrix = true;
        break;
      }
    }

    if (isMatrix) {
      return await _importMatrixCsv(rows, targetSwimmerId: targetSwimmerId, course: course);
    }

    // Standard Row-per-result format
    int importedCount = 0;
    
    // Find header row and column mapping
    int headerRowIdx = -1;
    Map<String, int> colMap = {};
    
    for (int i = 0; i < rows.length && i < 5; i++) {
      final row = rows[i].map((e) => e.toString().toLowerCase().replaceAll(' ', '')).toList();
      if (row.contains('firstname') || row.contains('surname') || row.contains('timems') || row.contains('distance')) {
        headerRowIdx = i;
        for (int j = 0; j < rows[i].length; j++) {
          final h = rows[i][j].toString().toLowerCase().replaceAll(' ', '');
          colMap[h] = j;
        }
        break;
      }
    }

    int startIndex = headerRowIdx != -1 ? headerRowIdx + 1 : 0;

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue; // Basic sanity check

      try {
        int? finalSwimmerId = targetSwimmerId;
        
        if (finalSwimmerId == null) {
          // If no target swimmer, must have names in row
          final fNameIdx = colMap['firstname'] ?? 0;
          final sNameIdx = colMap['surname'] ?? 1;
          if (row.length <= fNameIdx || row.length <= sNameIdx) continue;
          
          final firstName = row[fNameIdx].toString();
          final surname = row[sNameIdx].toString();
          final dobStr = colMap.containsKey('dob') && row.length > colMap['dob']! ? row[colMap['dob']!].toString() : null;
          final nationality = colMap.containsKey('nationality') && row.length > colMap['nationality']! ? row[colMap['nationality']!].toString() : 'Unknown';
          final club = colMap.containsKey('club') && row.length > colMap['club']! ? row[colMap['club']!]?.toString() : null;

          finalSwimmerId = await _dbHelper.getOrCreateSwimmer(
            Swimmer(
              firstName: firstName, 
              surname: surname, 
              dob: dobStr != null ? DateTime.tryParse(dobStr) ?? DateTime(2000) : DateTime(2000), 
              nationality: nationality, 
              gender: 'Female', 
              club: club,
            ),
          );
        }

        if (finalSwimmerId == null) continue;

        // Extract Meet Info
        final meetTitle = colMap.containsKey('meettitle') && row.length > colMap['meettitle']! ? row[colMap['meettitle']!].toString() : 'Bulk Import';
        final meetDateStr = colMap.containsKey('meetdate') && row.length > colMap['meetdate']! ? row[colMap['meetdate']!].toString() : null;
        final meetDate = meetDateStr != null ? DateTime.tryParse(meetDateStr) ?? DateTime.now() : DateTime.now();
        
        final rowCourseStr = colMap.containsKey('course') && row.length > colMap['course']! ? row[colMap['course']!].toString() : 'SCM';
        final rowCourse = _normalizeCourse(rowCourseStr);

        // Extract Event Info
        final distIdx = colMap['distance'] ?? 7;
        final strokeIdx = colMap['stroke'] ?? 8;
        final timeMsIdx = colMap['timems'] ?? colMap['time'] ?? 9;

        if (row.length <= timeMsIdx) continue;

        final distance = int.tryParse(row[distIdx].toString()) ?? 50;
        final stroke = _normalizeStroke(row[strokeIdx].toString());
        final timeMs = SwimEvent.parseTimeToMs(row[timeMsIdx].toString());
        
        if (timeMs == 0) continue;

        int meetId = await _dbHelper.getOrCreateMeet(
          SwimMeet(title: meetTitle, date: meetDate, course: course ?? rowCourse),
        );

        await _dbHelper.insertEvent(
          SwimEvent(meetId: meetId, swimmerId: finalSwimmerId, distance: distance, stroke: stroke, timeMs: timeMs),
        );
        importedCount++;
      } catch (e) {
        // Skip malformed row
      }
    }
    return importedCount;
  }

  String _normalizeStroke(String stroke) {
    final s = stroke.toLowerCase().trim();
    if (s.contains('free') || s == 'fr') return 'Freestyle';
    if (s.contains('back') || s == 'bk') return 'Backstroke';
    if (s.contains('breast') || s == 'br') return 'Breaststroke';
    if (s.contains('fly') || s.contains('butter') || s == 'fl') return 'Butterfly';
    if (RegExp(r'\bim\b', caseSensitive: false).hasMatch(s) || s.contains('medley')) return 'IM';
    return stroke;
  }

  String _normalizeCourse(String course) {
    final c = course.toLowerCase().trim();
    if (c.contains('25') || c.contains('scm') || c.contains('sc')) return 'SCM';
    if (c.contains('50') || c.contains('lcm') || c.contains('lc')) return 'LCM';
    return 'SCM'; // Default to SCM if unknown row-level course
  }

  Future<int> _importMatrixCsv(List<List<dynamic>> rows, {int? targetSwimmerId, String? course}) async {
    int dateRowIndex = -1;
    int meetRowIndex = -1;
    
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty) {
        final firstCell = rows[i][0].toString().trim().toLowerCase();
        if (firstCell == 'date') dateRowIndex = i;
        if (firstCell == 'meet name') meetRowIndex = i;
      }
      if (dateRowIndex != -1 && meetRowIndex != -1) break;
    }

    if (dateRowIndex == -1 || meetRowIndex == -1) return 0;

    final dateRow = rows[dateRowIndex];
    final meetRow = rows[meetRowIndex];

    int swimmerId;
    if (targetSwimmerId != null) {
      swimmerId = targetSwimmerId;
    } else {
      throw Exception('Target swimmer mandatory for matrix import');
    }

    int currentDistance = 50;
    int importedCount = 0;

    for (int i = meetRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final firstCell = row[0].toString().trim();
      if (firstCell.isEmpty) continue;

      // Distance update: check if cell starts with a known distance (e.g. "200 IM" or "200m IM")
      final distMatch = RegExp(r'\b(50|100|200|400|800|1500)\s*m?\b', caseSensitive: false).firstMatch(firstCell);
      if (distMatch != null) {
        currentDistance = int.parse(distMatch.group(1)!);
        // If it's ONLY a distance row (e.g. "200" or "200m"), continue to next row.
        // Otherwise (e.g. "200 IM"), keep processing this row as a stroke row.
        if (RegExp(r'^\s*(50|100|200|400|800|1500)\s*m?\s*$', caseSensitive: false).hasMatch(firstCell)) {
          continue;
        }
      }

      final stroke = _normalizeStroke(firstCell);
      // Validate it's a known stroke to avoid header rows
    if (['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'].contains(stroke)) {
        for (int j = 1; j < row.length; j++) {
          if (j >= dateRow.length || j >= meetRow.length) break;
          
          final timeStr = row[j].toString().trim();
          if (timeStr.isEmpty || timeStr == ',' || timeStr == '-') continue;

          final dateStr = dateRow[j].toString().trim();
          final meetTitle = meetRow[j].toString().trim();

          if (dateStr.isEmpty || meetTitle.isEmpty) continue;

          DateTime? date;
          try {
            // Support "DD Mon YYYY" or ISO
            final parts = dateStr.replaceAll('-', ' ').replaceAll('/', ' ').split(' ').where((p) => p.isNotEmpty).toList();
            if (parts.length == 3 && parts[1].toLowerCase().contains(RegExp(r'[a-z]'))) {
              final day = int.parse(parts[0]);
              final year = int.parse(parts[2]);
              final monthStr = parts[1].toLowerCase();
              int month = 1;
              const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
              final monthIdx = months.indexWhere((m) => monthStr.startsWith(m));
              if (monthIdx != -1) month = monthIdx + 1;
              date = DateTime(year, month, day);
            } else {
              date = DateTime.parse(dateStr);
            }
          } catch (e) { /* skip */ }
          
          if (date == null) continue;

          int meetId = await _dbHelper.getOrCreateMeet(
            SwimMeet(title: meetTitle, date: date, course: course ?? 'LCM'),
          );

          int timeMs = SwimEvent.parseTimeToMs(timeStr);
          if (timeMs > 0) {
            await _dbHelper.insertEvent(
              SwimEvent(meetId: meetId, swimmerId: swimmerId, distance: currentDistance, stroke: stroke, timeMs: timeMs),
            );
            importedCount++;
          }
        }
      }
    }
    return importedCount;
  }

  Future<int> _importSwimmer(Map<String, dynamic> swimmerData) async {
    int importedCount = 0;
    final swimmerId = await _dbHelper.getOrCreateSwimmer(
      Swimmer(
        firstName: swimmerData['firstName'],
        surname: swimmerData['surname'],
        photoPath: swimmerData['photoPath'],
        dob: DateTime.parse(swimmerData['dob']),
        nationality: swimmerData['nationality'],
        gender: swimmerData['gender'] ?? 'Female',
      ),
    );
    
    if (swimmerData.containsKey('meets')) {
      for (var meetData in swimmerData['meets']) {
        importedCount += await _importMeet(meetData, swimmerId);
      }
    }
    return importedCount;
  }

  Future<int> _importMeet(Map<String, dynamic> meetData, int swimmerId) async {
    int importedCount = 0;
    final meetId = await _dbHelper.getOrCreateMeet(
      SwimMeet(
        title: meetData['title'],
        date: DateTime.parse(meetData['date']),
        course: meetData['course'],
      ),
    );
    
    if (meetData.containsKey('events')) {
      for (var eventData in meetData['events']) {
        final event = SwimEvent(
          meetId: meetId,
          swimmerId: swimmerId,
          distance: eventData['distance'],
          stroke: _normalizeStroke(eventData['stroke']),
          timeMs: eventData['timeMs'],
        );
        await _dbHelper.insertEvent(event);
        importedCount++;
      }
    }
    return importedCount;
  }
}
