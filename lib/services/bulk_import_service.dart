import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/swimmer.dart';
import '../models/meet.dart';
import '../models/event.dart';
import '../models/goal.dart';
import '../utils/time_utils.dart';

class BulkImportService {
  final DatabaseHelper _dbHelper;
  final _textRecognizer = TextRecognizer();
  // Support MM:SS.hh or SS.hh or TimeMs (only 5-7 digits to avoid years)
  // We use [.:,] as separators and ensure no dashes are adjacent to avoid matching dates
  static final _universalTimeRegex = RegExp(r'(?<![\-\d])(\d{1,2}[\:\.\,]\d{1,2}[\:\.\,]\d{1,2})(?![\-\d])|(?<![\-\d])(\d{1,2}[\:\.\,]\d{1,2})(?![\-\d])|(\b\d{5,7}\b)');

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
    
    if (extension == 'zip') {
      final bytes = await file.readAsBytes();
      return await importFromZip(bytes, targetSwimmerId: targetSwimmerId, course: course);
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
    return await _dbHelper.transaction((txn) async {
      final excel = Excel.decodeBytes(bytes);
      int totalImported = 0;
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        final List<List<dynamic>> rows = sheet.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
        
        // Extract images manually from the archive
        final Map<int, Uint8List> rowToImage = await _extractXlsxImages(archive, table, rows);
        
        final count = await _importFromRows(rows, targetSwimmerId: targetSwimmerId, course: course, rowImages: rowToImage, sheetName: table, executor: txn);
        totalImported += count;
      }
      return totalImported;
    });
  }

  Future<int> importFromZip(Uint8List bytes, {int? targetSwimmerId, String? course}) async {
    return await _dbHelper.transaction((txn) async {
      final archive = ZipDecoder().decodeBytes(bytes);
      Uint8List? xlsxBytes;
      final Map<String, Uint8List> externalFiles = {};
      
      for (final file in archive) {
        if (file.isFile) {
          if (file.name.endsWith('.xlsx')) {
            xlsxBytes = Uint8List.fromList(file.content);
          } else {
            // Store photos (can be in subfolders like 'photos/')
            externalFiles[file.name] = Uint8List.fromList(file.content);
            // Also store by basename for easier lookup
            externalFiles[file.name.split('/').last] = Uint8List.fromList(file.content);
          }
        }
      }

      if (xlsxBytes == null) throw Exception('No .xlsx file found in ZIP');

      final excel = Excel.decodeBytes(xlsxBytes);
      int totalImported = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        final List<List<dynamic>> rows = sheet.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
        
        // Map external files to rows
        final Map<int, Uint8List> rowToImage = {};
        if (rows.isNotEmpty) {
          final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
          final photoFileIdx = header.indexOf('photofile');
          
          if (photoFileIdx != -1) {
            for (int i = 1; i < rows.length; i++) {
              if (rows[i].length > photoFileIdx) {
                final fileName = rows[i][photoFileIdx].toString().toLowerCase().trim();
                if (fileName.isNotEmpty && (externalFiles.containsKey(fileName) || externalFiles.containsKey(fileName.toLowerCase()))) {
                  rowToImage[i] = externalFiles[fileName] ?? externalFiles[fileName.toLowerCase()]!;
                }
              }
            }
          }
        }

        final count = await _importFromRows(rows, targetSwimmerId: targetSwimmerId, course: course, rowImages: rowToImage, sheetName: table, executor: txn);
        totalImported += count;
      }
      return totalImported;
    });
  }

  Future<int> importFromJson(String jsonString) async {
    return await _dbHelper.transaction((txn) async {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      int importedCount = 0;
      
      if (data.containsKey('swimmers')) {
        for (var swimmerData in data['swimmers']) {
          importedCount += await _importSwimmer(swimmerData, executor: txn);
        }
      }
      return importedCount;
    });
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
    
    return await _dbHelper.transaction((txn) async {
      return await _importFromRows(rows, targetSwimmerId: targetSwimmerId, course: course, executor: txn);
    });
  }

  Future<String?> _saveSwimmerPhoto(String firstName, String surname, Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final portraitsDir = Directory('${appDir.path}/portraits');
      if (!await portraitsDir.exists()) {
        await portraitsDir.create(recursive: true);
      }
      
      String first = firstName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      String sur = surname.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final fileName = '${first}_${sur}_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${portraitsDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<Map<int, Uint8List>> _extractXlsxImages(Archive archive, String sheetName, List<List<dynamic>> rows) async {
    final Map<int, Uint8List> rowToImage = {};
    try {
      int imageColIdx = -1;
      if (rows.isNotEmpty) {
        final header = rows.first.map((e) => e.toString().toLowerCase().replaceAll(' ', '').replaceAll('_', '')).toList();
        final synonyms = ['image', 'photo', 'picture', 'portrait', 'profile', 'swimmerphoto', 'swimmerimage'];
        for (var syn in synonyms) {
          imageColIdx = header.indexOf(syn);
          if (imageColIdx != -1) break;
        }
      }

      // 1. Find the sheet file path and drawing relationship
      final workbookFile = archive.findFile('xl/workbook.xml');
      if (workbookFile == null) return {};
      final workbookDoc = XmlDocument.parse(utf8.decode(workbookFile.content));
      final sheetNode = workbookDoc.findAllElements('sheet').firstWhere(
        (node) => node.getAttribute('name') == sheetName,
        orElse: () => throw Exception('Sheet not found'),
      );
      final rId = sheetNode.getAttribute('r:id');

      final workbookRelsFile = archive.findFile('xl/_rels/workbook.xml.rels');
      if (workbookRelsFile == null) return {};
      final workbookRelsDoc = XmlDocument.parse(utf8.decode(workbookRelsFile.content));
      final sheetRelNode = workbookRelsDoc.findAllElements('Relationship').firstWhere(
        (node) => node.getAttribute('Id') == rId,
      );

      // 2. Find drawing for this sheet
      final sheetRelsPath = 'xl/worksheets/_rels/${sheetRelNode.getAttribute('Target')!.split('/').last}.rels';
      final sheetRelsFile = archive.findFile(sheetRelsPath);
      if (sheetRelsFile == null) return {};
      final sheetRelsDoc = XmlDocument.parse(utf8.decode(sheetRelsFile.content));
      final drawingRelNode = sheetRelsDoc.findAllElements('Relationship').firstWhere(
        (node) => node.getAttribute('Type')!.contains('drawing'),
        orElse: () => throw Exception('No drawing for sheet'),
      );
      final drawingPath = 'xl/drawings/${drawingRelNode.getAttribute('Target')!.split('/').last}';

      // 3. Parse drawing XML
      final drawingFile = archive.findFile(drawingPath);
      if (drawingFile == null) return {};
      final drawingDoc = XmlDocument.parse(utf8.decode(drawingFile.content));

      // 4. Parse drawing relationships
      final drawingRelsPath = 'xl/drawings/_rels/${drawingRelNode.getAttribute('Target')!.split('/').last}.rels';
      final drawingRelsFile = archive.findFile(drawingRelsPath);
      if (drawingRelsFile == null) return {};
      final drawingRelsDoc = XmlDocument.parse(utf8.decode(drawingRelsFile.content));
      final Map<String, String> imagePathMap = {};
      for (var rel in drawingRelsDoc.findAllElements('Relationship')) {
        imagePathMap[rel.getAttribute('Id')!] = rel.getAttribute('Target')!;
      }

      // 5. Map anchors to images
      final anchors = [
        ...drawingDoc.findAllElements('xdr:twoCellAnchor'),
        ...drawingDoc.findAllElements('twoCellAnchor'),
        ...drawingDoc.findAllElements('xdr:oneCellAnchor'),
        ...drawingDoc.findAllElements('oneCellAnchor'),
      ];

      for (var anchor in anchors) {
        final fromNode = anchor.descendants.whereType<XmlElement>().firstWhere(
          (e) => e.name.local == 'from',
          orElse: () => throw Exception('no from'),
        );
        final rowNode = fromNode.findElements('xdr:row').firstOrNull ?? fromNode.findElements('row').firstOrNull;
        final colNode = fromNode.findElements('xdr:col').firstOrNull ?? fromNode.findElements('col').firstOrNull;
        
        if (rowNode == null || colNode == null) continue;

        final row = int.parse(rowNode.innerText);
        final col = int.parse(colNode.innerText);

        final pic = anchor.descendants.whereType<XmlElement>().firstWhere(
          (e) => e.name.local == 'pic',
          orElse: () => XmlElement(XmlName('null')),
        );
        if (pic.name.local == 'pic') {
          final blip = pic.descendants.whereType<XmlElement>().firstWhere(
            (e) => e.name.local == 'blip',
            orElse: () => XmlElement(XmlName('null')),
          );
          
          String? embedId;
          for (var attr in blip.attributes) {
            if (attr.name.local == 'embed') {
              embedId = attr.value;
              break;
            }
          }

          if (embedId != null && imagePathMap.containsKey(embedId)) {
            var targetMedia = imagePathMap[embedId]!;
            // Target might be ../media/image1.png
            final mediaFileName = targetMedia.split('/').last;
            final mediaPath = 'xl/media/$mediaFileName';
            
            final mediaFile = archive.findFile(mediaPath);
            if (mediaFile != null) {
              if (imageColIdx == -1 || col == imageColIdx) {
                rowToImage[row] = Uint8List.fromList(mediaFile.content);
              }
            }
          }
        }
      }
    } catch (e) {
      // If anything fails, return empty map
    }
    return rowToImage;
  }

  Future<int> importReviewedResults(int swimmerId, String defaultMeetTitle, DateTime defaultMeetDate, String course, List<Map<String, dynamic>> results) async {
    return await _dbHelper.transaction((txn) async {
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
              executor: txn,
            );
            meetIdCache[cacheKey] = meetId;
          }

          final event = SwimEvent(
            meetId: meetId,
            swimmerId: swimmerId,
            distance: res['distance'],
            stroke: res['stroke'],
            timeMs: TimeUtils.parseTimeToMs(res['time']),
          );
          await _dbHelper.insertEvent(event, executor: txn);
          importedCount++;
        } catch (e) {
          // Skip malformed result
        }
      }
      return importedCount;
    });
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
    
    // Try Matrix OCR (Table based)
    final grid = _reconstructGrid(recognizedText);
    if (_isMatrixGrid(grid)) {
      final results = _extractFromMatrixGrid(grid);
      if (results.isNotEmpty) return results;
    }
    
    // Try Standard Grid (Row per result)
    if (_isStandardGrid(grid)) {
      final results = _extractFromStandardGrid(grid);
      if (results.isNotEmpty) return results;
    }
    
    // Fallback to line-by-line (sorted by Y then X)
    final List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) {
      final yCompare = a.boundingBox.top.compareTo(b.boundingBox.top);
      if (yCompare.abs() > 10) return yCompare; 
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final sortedText = allLines.map((l) => l.text).join('\n');
    return _parseResultsFromText(sortedText);
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
          // Relaxed matching for MM:SS.hh or SS.hh or TimeMs
          final normalizedTime = _normalizeTime(timeStr);
          final timeMs = TimeUtils.parseTimeToMs(normalizedTime);
          if (timeMs > 0) {
            extracted.add({
              'distance': currentDistance,
              'stroke': stroke,
              'time': normalizedTime,
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
      final row = grid[i].map((s) => s.toLowerCase().replaceAll(' ', '').trim()).toList();
      int matches = 0;
      if (row.any((c) => c.contains('first') || c.contains('name'))) matches++;
      if (row.any((c) => c.contains('sur') || c.contains('last'))) matches++;
      if (row.any((c) => c.contains('time') || c.contains('res'))) matches++;
      if (row.any((c) => c.contains('dist'))) matches++;
      if (matches >= 2) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _extractFromStandardGrid(List<List<String>> grid) {
    if (grid.isEmpty) return [];

    // Find header row
    int headerRowIdx = -1;
    for (int i = 0; i < grid.length; i++) {
      final row = grid[i].map((s) => s.toLowerCase().replaceAll(' ', '').trim()).toList();
      // Look for a row that has at least two key swimming headers
      int matches = 0;
      if (row.any((c) => c.contains('first') || c.contains('name'))) matches++;
      if (row.any((c) => c.contains('sur') || c.contains('last'))) matches++;
      if (row.any((c) => c.contains('time') || c.contains('res'))) matches++;
      if (row.any((c) => c.contains('dist'))) matches++;
      
      if (matches >= 2) {
        headerRowIdx = i;
        break;
      }
    }

    if (headerRowIdx == -1) return [];

    final headers = grid[headerRowIdx].map((e) => e.toLowerCase().replaceAll(' ', '')).toList();
    
    // Find column indices
    final firstNameIdx = headers.indexWhere((h) => h.contains('first') || h.contains('given'));
    final surnameIdx = headers.indexWhere((h) => h.contains('sur') || h.contains('last') || h.contains('family'));
    final meetTitleIdx = headers.indexWhere((h) => h.contains('meet') && h.contains('title'));
    final meetDateIdx = headers.indexWhere((h) => h.contains('meet') && h.contains('date'));
    final distanceIdx = headers.indexWhere((h) => h.contains('dist'));
    final strokeIdx = headers.indexWhere((h) => h.contains('stroke'));
    final timeMsIdx = headers.indexWhere((h) => (h.contains('time') || h.contains('result')) && !h.contains('date'));
    final courseIdx = headers.indexWhere((h) => h.contains('course'));
    final dobIdx = headers.indexWhere((h) => h.contains('dob') || (h.contains('birth') && h.contains('date')));
    final nationalityIdx = headers.indexWhere((h) => h.contains('nation') || h.contains('nat'));

    if (timeMsIdx == -1) return [];

    final List<Map<String, dynamic>> extracted = [];
    for (int i = headerRowIdx + 1; i < grid.length; i++) {
      List<String> row = grid[i];
      if (row.isEmpty) continue;

      // If the row is very compact (e.g. OCR merged columns), try to split it
      if (row.length < 3 && row.any((c) => c.contains(' '))) {
        final List<String> splitRow = <String>[];
        for (var cell in row) {
          // Split by common boundaries: spaces followed by digits or strokes
          final splitParts = cell.split(RegExp(r'\s+(?=\d|Butterfly|Back|Breast|Free|IM)', caseSensitive: false));
          splitRow.addAll(splitParts.where((p) => p.isNotEmpty));
        }
        if (splitRow.isNotEmpty) {
          row = splitRow;
        }
      }

      // If we don't have a timeMsIdx, try to find the FIRST cell that looks like a time
      int effectiveTimeIdx = timeMsIdx;
      if (effectiveTimeIdx == -1) {
        effectiveTimeIdx = row.indexWhere((c) => _universalTimeRegex.hasMatch(c));
      }
      
      if (effectiveTimeIdx == -1 || row.length <= effectiveTimeIdx) continue;

      try {
        final distanceStr = distanceIdx != -1 && row.length > distanceIdx ? row[distanceIdx] : '50';
        final distance = int.tryParse(RegExp(r'\d+').firstMatch(distanceStr)?.group(0) ?? '50') ?? 50;
        final strokeVal = strokeIdx != -1 && row.length > strokeIdx ? row[strokeIdx] : 'Freestyle';
        final stroke = _normalizeStroke(strokeVal);
        final timeMsStr = row[effectiveTimeIdx].trim();

        
        final courseStr = courseIdx != -1 && row.length > courseIdx ? row[courseIdx] : null;
        final resCourse = courseStr != null ? _normalizeCourse(courseStr) : null;

        if (timeMsStr.isEmpty) continue;
        
        // and doesn't have a valid distance/stroke, skip it.
        if (row.any((cell) => cell.contains('-') || cell.contains('T00:00:00'))) {
           // Verify we actually have distance and stroke before accepting
           if (distance == 50 && stroke == 'Freestyle' && !row.any((c) => c.toLowerCase().contains('free'))) {
             // Likely a false positive from a metadata/date row
             continue;
           }
        }

        final formattedTime = _normalizeTime(timeMsStr);
        final timeMs = TimeUtils.parseTimeToMs(formattedTime);
        
        // CRITICAL: Reject if time is 0 or couldn't be parsed
        if (timeMs <= 0) continue;

        // If normalization resulted in a very small time (e.g. 2.00 from a year), it's probably wrong
        if (formattedTime == '2.00' || formattedTime == '20.00' || formattedTime == '20.08') {
           if (!timeMsStr.contains('.') && !timeMsStr.contains(':')) continue;
        }

        // Avoid importing header names as meet titles
        String? finalMeetTitle = meetTitleIdx != -1 && row.length > meetTitleIdx ? row[meetTitleIdx].trim() : null;
        if (finalMeetTitle != null) {
          final lowTitle = finalMeetTitle.toLowerCase();
          if (lowTitle == 'meet' || lowTitle == 'title' || lowTitle == 'meettitle' || lowTitle == 'date' || lowTitle == 'event') {
            finalMeetTitle = null; 
          }
        }

        extracted.add({
          'firstName': firstNameIdx != -1 && row.length > firstNameIdx ? row[firstNameIdx] : null,
          'surname': surnameIdx != -1 && row.length > surnameIdx ? row[surnameIdx] : null,
          'dob': dobIdx != -1 && row.length > dobIdx ? row[dobIdx] : null,
          'nationality': nationalityIdx != -1 && row.length > nationalityIdx ? row[nationalityIdx] : 'GB',
          'distance': distance,
          'stroke': stroke,
          'time': formattedTime,
          'course': resCourse,
          'meetTitle': finalMeetTitle,
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

    // Group by Y into initial rows with a slightly larger tolerance for skewed images
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final List<List<TextLine>> tempRows = [];
    if (allLines.isNotEmpty) {
      List<TextLine> currentRow = [allLines.first];
      for (int i = 1; i < allLines.length; i++) {
        final line = allLines[i];
        final prevLine = currentRow.last;
        // Increase tolerance to 80% of height to handle slight tilts
        final tolerance = prevLine.boundingBox.height * 0.8;
        if ((line.boundingBox.top - prevLine.boundingBox.top).abs() < tolerance) {
          currentRow.add(line);
        } else {
          tempRows.add(currentRow);
          currentRow = [line];
        }
      }
      tempRows.add(currentRow);
    }

    // Sort each row by X
    for (var row in tempRows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }

    // Identify ALL potential column anchors from all rows, not just headers
    // This helps with sparse tables where the header might be missing or mangled.
    final List<double> allXOffsets = [];
    for (var row in tempRows) {
      for (var line in row) {
        allXOffsets.add(line.boundingBox.left);
      }
    }
    allXOffsets.sort();
    
    // Cluster X offsets into columns using a dynamic threshold based on average text height
    final List<double> colAnchors = [];
    if (allXOffsets.isNotEmpty) {
      double avgHeight = 0;
      int lineCount = 0;
      for (var row in tempRows) {
        for (var line in row) {
          avgHeight += line.boundingBox.height;
          lineCount++;
        }
      }
      final threshold = lineCount > 0 ? (avgHeight / lineCount) * 1.5 : 50.0;

      double currentAnchor = allXOffsets.first;
      List<double> currentCluster = [currentAnchor];
      for (int i = 1; i < allXOffsets.length; i++) {
        if (allXOffsets[i] - currentAnchor < threshold) { 
          currentCluster.add(allXOffsets[i]);
        } else {
          colAnchors.add(currentCluster.reduce((a, b) => a + b) / currentCluster.length);
          currentAnchor = allXOffsets[i];
          currentCluster = [currentAnchor];
        }
      }
      colAnchors.add(currentCluster.reduce((a, b) => a + b) / currentCluster.length);
    }

    // Reconstruct grid by mapping each line to the nearest column anchor
    final resultGrid = <List<String>>[];
    for (var row in tempRows) {
      final gridRow = List.filled(colAnchors.length, '');
      for (var line in row) {
        int bestCol = 0;
        double minDist = double.infinity;
        for (int c = 0; c < colAnchors.length; c++) {
          final dist = (line.boundingBox.left - colAnchors[c]).abs();
          if (dist < minDist) {
            minDist = dist;
            bestCol = c;
          }
        }
        if (gridRow[bestCol].isEmpty) {
          gridRow[bestCol] = line.text;
        } else {
          // Append with space if it seems to be part of the same cell
          gridRow[bestCol] += ' ${line.text}';
        }
      }
      
      // Post-process row: Split monolithic cells (e.g., "50m Free 32.50")
      final List<String> sanitizedRow = [];
      for (var cell in gridRow) {
        // If a cell contains a time and something else, split it?
        // For now, just keep it, but the extraction logic should be aware
        sanitizedRow.add(cell);
      }
      resultGrid.add(sanitizedRow);
    }
    return resultGrid;
  }

  String _normalizeTime(String timeStr) {
    final match = _universalTimeRegex.firstMatch(timeStr.trim());
    if (match == null) return timeStr;
    
    final matchedText = match.group(0)!;
    if (RegExp(r'^\d{4,7}$').hasMatch(matchedText)) {
      final ms = int.parse(matchedText);
      return TimeUtils.formatTime(ms);
    }
    return matchedText;
  }

  List<Map<String, dynamic>> _parseResultsFromText(String text) {
    final List<Map<String, dynamic>> extracted = [];
    final lines = text.split('\n');

    int currentDistance = 50;
    String currentStroke = 'Freestyle';
    String? currentMeet;
    String? currentDate;

    final distanceRegex = RegExp(r'\b(50|100|200|400|800|1500)\b', caseSensitive: false);
    final strokeRegex = RegExp(r'\b(Freestyle|Free|Fr|Backstroke|Back|Bk|Breaststroke|Breast|Br|Butterfly|Fly|Fl|IM|Medley|Individual Medley)\b', caseSensitive: false);
    final meetHeaderRegex = RegExp(r'(Meet|Championships|Gala|Open)\s*[:\-]?\s*(.+)', caseSensitive: false);
    final dateRegex = RegExp(r'\b(\d{1,2}[/\-\.\s]([A-Z][a-z]{2}|\d{1,2})[/\-\.\s]\d{2,4})\b');

    for (var line in lines) {
      final cleanedLine = line.trim();
      if (cleanedLine.isEmpty) continue;

      // Update state if line contains distance or stroke as a header
      final distMatch = distanceRegex.firstMatch(cleanedLine);
      final strokeMatch = strokeRegex.firstMatch(cleanedLine);
      final timeMatch = _universalTimeRegex.firstMatch(cleanedLine);
      final meetMatch = meetHeaderRegex.firstMatch(cleanedLine);
      final dateMatch = dateRegex.firstMatch(cleanedLine);

      if (meetMatch != null) currentMeet = meetMatch.group(2)?.trim();
      if (dateMatch != null) currentDate = dateMatch.group(1);

      // If a line is ONLY a distance or stroke, it's likely a header
      final isOnlyDistance = distMatch != null && cleanedLine.length < 10 && timeMatch == null;
      final isOnlyStroke = strokeMatch != null && cleanedLine.length < 20 && timeMatch == null;

      if (isOnlyDistance) {
        currentDistance = int.parse(distMatch.group(1)!);
        // Sometimes stroke is on the same header line as distance
        if (strokeMatch != null) currentStroke = _normalizeStroke(strokeMatch.group(1)!);
        continue;
      }

      if (isOnlyStroke) {
        currentStroke = _normalizeStroke(strokeMatch.group(1)!);
        continue;
      }

      // If we find a time, build a result using the current state
      if (timeMatch != null) {
        // Look for local distance/stroke override on the same line
        int rowDistance = distMatch != null ? int.parse(distMatch.group(1)!) : currentDistance;
        String rowStroke = strokeMatch != null ? _normalizeStroke(strokeMatch.group(1)!) : currentStroke;

        final normalizedTime = _normalizeTime(timeMatch.group(0)!);
        final timeMs = TimeUtils.parseTimeToMs(normalizedTime);

        if (timeMs > 0) {
          extracted.add({
            'distance': rowDistance,
            'stroke': rowStroke,
            'time': normalizedTime,
            'meetTitle': currentMeet,
            'meetDate': currentDate,
            'original': cleanedLine,
          });
        }
      }
    }
    return extracted;
  }

  Future<int> _importFromRows(List<List<dynamic>> rows, {int? targetSwimmerId, String? course, Map<int, Uint8List>? rowImages, String? sheetName, DatabaseExecutor? executor}) async {
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
      return await _importMatrixCsv(rows, targetSwimmerId: targetSwimmerId, course: course, executor: executor);
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

    int? activeSwimmerId = targetSwimmerId;
    
    // Fallback: If no target swimmer and sheetName looks like a name, pre-create/lookup swimmer
    if (activeSwimmerId == null && sheetName != null && !_isGenericSheetName(sheetName)) {
      final parts = _parseName(sheetName);
      if (parts != null) {
        activeSwimmerId = await _dbHelper.getOrCreateSwimmer(
          Swimmer(
            firstName: parts['first']!,
            surname: parts['last']!,
            dob: DateTime(2000),
            nationality: 'Unknown',
            gender: 'Female',
          ),
          executor: executor,
        );
      }
    }

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue; // Basic sanity check

      try {
        // Check if this row provides a new swimmer name
        final fNameIdx = colMap['firstname'];
        final sNameIdx = colMap['surname'];
        
        if (fNameIdx != null && sNameIdx != null && 
            row.length > fNameIdx && row.length > sNameIdx &&
            row[fNameIdx].toString().trim().isNotEmpty && 
            row[sNameIdx].toString().trim().isNotEmpty) {
          
          final firstName = row[fNameIdx].toString().trim();
          final surname = row[sNameIdx].toString().trim();
          final dobStr = colMap.containsKey('dob') && row.length > colMap['dob']! ? row[colMap['dob']!].toString() : null;
          final nationality = colMap.containsKey('nationality') && row.length > colMap['nationality']! ? row[colMap['nationality']!].toString() : 'Unknown';
          final club = colMap.containsKey('club') && row.length > colMap['club']! ? row[colMap['club']!]?.toString() : null;
          final gender = colMap.containsKey('gender') && row.length > colMap['gender']! ? row[colMap['gender']!].toString() : 'Female';
          
          String? photoPath;
          if (rowImages != null && rowImages.containsKey(i)) {
            photoPath = await _saveSwimmerPhoto(firstName, surname, rowImages[i]!);
          }

          activeSwimmerId = await _dbHelper.getOrCreateSwimmer(
            Swimmer(
              firstName: firstName, 
              surname: surname, 
              photoPath: photoPath,
              dob: dobStr != null ? DateTime.tryParse(dobStr) ?? DateTime(2000) : DateTime(2000), 
              nationality: nationality, 
              gender: gender, 
              club: club,
            ),
            executor: executor,
          );
        }

        if (activeSwimmerId == null) continue;
        int finalSwimmerId = activeSwimmerId;

        // Extract Meet Info
        final meetTitle = colMap.containsKey('meettitle') && row.length > colMap['meettitle']! ? row[colMap['meettitle']!].toString() : 'Bulk Import';
        final meetDateStr = colMap.containsKey('meetdate') && row.length > colMap['meetdate']! ? row[colMap['meetdate']!].toString() : null;
        final meetDate = meetDateStr != null ? DateTime.tryParse(meetDateStr) ?? DateTime.now() : DateTime.now();
        
        final rowCourseStr = colMap.containsKey('course') && row.length > colMap['course']! ? row[colMap['course']!].toString() : 'SCM';
        final rowCourse = _normalizeCourse(rowCourseStr);

        // Extract Event Club
        final club = colMap.containsKey('club') && row.length > colMap['club']! ? row[colMap['club']!]?.toString() : null;

        // Extract Event Info
        final distIdx = colMap['distance'] ?? 7;
        final strokeIdx = colMap['stroke'] ?? 8;
        final timeMsIdx = colMap['timems'] ?? colMap['time'] ?? 9;

        if (row.length <= timeMsIdx) continue;

        final distance = int.tryParse(row[distIdx].toString()) ?? 50;
        final stroke = _normalizeStroke(row[strokeIdx].toString());
        final timeMs = TimeUtils.parseTimeToMs(row[timeMsIdx].toString());
        
        final dataType = colMap.containsKey('datatype') && row.length > colMap['datatype']! 
            ? row[colMap['datatype']!].toString().toLowerCase().trim() 
            : 'result';

        if (dataType == 'goal') {
          await _dbHelper.insertGoal(
            SwimmerGoal(
              swimmerId: finalSwimmerId,
              distance: distance,
              stroke: stroke,
              course: course ?? rowCourse,
              timeMs: timeMs,
              targetDate: meetDate,
            ),
            executor: executor,
          );
        } else {
          int meetId = await _dbHelper.getOrCreateMeet(
            SwimMeet(title: meetTitle, date: meetDate, course: course ?? rowCourse),
            executor: executor,
          );

          await _dbHelper.insertEvent(
            SwimEvent(
              meetId: meetId, 
              swimmerId: finalSwimmerId, 
              distance: distance, 
              stroke: stroke, 
              timeMs: timeMs,
              club: club,
            ),
            executor: executor,
          );
        }
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
    return 'Freestyle'; // Safe default for UI dropdown compatibility
  }

  String _normalizeCourse(String course) {
    final c = course.toLowerCase().trim();
    if (c.contains('25') || c.contains('scm') || c.contains('sc')) return 'SCM';
    if (c.contains('50') || c.contains('lcm') || c.contains('lc')) return 'LCM';
    return 'SCM'; // Default to SCM if unknown row-level course
  }

  Future<int> _importMatrixCsv(List<List<dynamic>> rows, {int? targetSwimmerId, String? course, DatabaseExecutor? executor}) async {
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
            executor: executor,
          );

          int timeMs = TimeUtils.parseTimeToMs(timeStr);
          if (timeMs > 0) {
            await _dbHelper.insertEvent(
              SwimEvent(meetId: meetId, swimmerId: swimmerId, distance: currentDistance, stroke: stroke, timeMs: timeMs),
              executor: executor,
            );
            importedCount++;
          }
        }
      }
    }
    return importedCount;
  }

  Future<int> _importSwimmer(Map<String, dynamic> swimmerData, {DatabaseExecutor? executor}) async {
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
      executor: executor,
    );
    
    if (swimmerData.containsKey('meets')) {
      for (var meetData in swimmerData['meets']) {
        importedCount += await _importMeet(meetData, swimmerId, executor: executor);
      }
    }
    return importedCount;
  }

  Future<int> _importMeet(Map<String, dynamic> meetData, int swimmerId, {DatabaseExecutor? executor}) async {
    int importedCount = 0;
    final meetId = await _dbHelper.getOrCreateMeet(
      SwimMeet(
        title: meetData['title'],
        date: DateTime.parse(meetData['date']),
        course: meetData['course'],
      ),
      executor: executor,
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
        await _dbHelper.insertEvent(event, executor: executor);
        importedCount++;
      }
    }
    return importedCount;
  }

  bool _isGenericSheetName(String name) {
    final n = name.toLowerCase().trim();
    return n.startsWith('sheet') || n == 'workbook' || n == 'results' || n == 'data' || n == 'swimmers' || n == 'team';
  }

  Map<String, String>? _parseName(String name) {
    // Try "Surname, Firstname"
    if (name.contains(',')) {
      final parts = name.split(',');
      if (parts.length >= 2) {
        return {
          'last': parts[0].trim(),
          'first': parts[1].trim(),
        };
      }
    }
    // Try "Firstname Surname"
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return {
        'first': parts[0].trim(),
        'last': parts.sublist(1).join(' ').trim(),
      };
    }
    return null;
  }
}
