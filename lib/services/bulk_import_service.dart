import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../database_helper.dart';
import '../models/swimmer.dart';
import '../models/meet.dart';
import '../models/event.dart';

class BulkImportService {
  final DatabaseHelper _dbHelper;

  BulkImportService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<int> importFromFile(File file, {int? targetSwimmerId, String? course}) async {
    final extension = file.path.split('.').last.toLowerCase();
    final content = await file.readAsString();

    if (extension == 'json') {
      return await importFromJson(content);
    } else if (extension == 'csv') {
      return await importFromCsv(content, targetSwimmerId: targetSwimmerId, course: course);
    } else {
      throw Exception('Unsupported file format: $extension');
    }
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
    int startIndex = 0;
    if (rows[0][0].toString().toLowerCase() == 'firstname') {
      startIndex = 1;
    }

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 10) continue;

      try {
        final firstName = row[0].toString();
        final surname = row[1].toString();
        final dob = DateTime.parse(row[2].toString());
        final nationality = row[3].toString();
        final meetTitle = row[4].toString();
        final meetDate = DateTime.parse(row[5].toString());
        final rowCourse = _normalizeCourse(row[6].toString());
        final distance = int.parse(row[7].toString());
        final stroke = _normalizeStroke(row[8].toString());
        final timeMs = int.parse(row[9].toString());
        
        // Optional club column (at index 10 if exists)
        String? club;
        if (row.length > 10) {
          club = row[10].toString();
        }

        int swimmerId = await _dbHelper.getOrCreateSwimmer(
          Swimmer(
            firstName: firstName, 
            surname: surname, 
            dob: dob, 
            nationality: nationality, 
            gender: 'Female', // Default for import
            club: club,
          ),
        );

        int meetId = await _dbHelper.getOrCreateMeet(
          SwimMeet(title: meetTitle, date: meetDate, course: course ?? rowCourse),
        );

        await _dbHelper.insertEvent(
          SwimEvent(meetId: meetId, swimmerId: swimmerId, distance: distance, stroke: stroke, timeMs: timeMs),
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
    if (s.contains('free')) return 'Freestyle';
    if (s.contains('back')) return 'Backstroke';
    if (s.contains('breast')) return 'Breaststroke';
    if (s.contains('fly') || s.contains('butter')) return 'Butterfly';
    if (s.contains('im') || s.contains('medley')) return 'IM';
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

      if (firstCell.toLowerCase().endsWith('m')) {
        final distStr = firstCell.toLowerCase().replaceAll('m', '').trim();
        currentDistance = int.tryParse(distStr) ?? currentDistance;
        continue;
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
