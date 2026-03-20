import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../database_helper.dart';

class BulkExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getSwimmerCsvContent(int swimmerId) async {
    final events = await _dbHelper.getEventsForExport(swimmerId);
    
    List<List<dynamic>> rows = [];
    
    // Add header
    rows.add([
      'FirstName', 
      'Surname', 
      'DOB', 
      'Nationality', 
      'MeetTitle', 
      'MeetDate', 
      'Course', 
      'Distance', 
      'Stroke', 
      'TimeMs', 
      'Club'
    ]);

    for (var event in events) {
      rows.add([
        event['firstName'],
        event['surname'],
        event['dob'],
        event['nationality'],
        event['meetTitle'],
        event['meetDate'],
        event['course'],
        event['distance'],
        event['stroke'],
        event['timeMs'],
        event['club'] ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<Uint8List?> getSwimmerXlsxBytes(int swimmerId) async {
    final events = await _dbHelper.getEventsForExport(swimmerId);
    var excel = Excel.createExcel();
    
    // Get the default sheet name
    String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    var sheet = excel[sheetName];
    
    // Header
    sheet.appendRow([
      TextCellValue('FirstName'), 
      TextCellValue('Surname'), 
      TextCellValue('DOB'), 
      TextCellValue('Nationality'), 
      TextCellValue('MeetTitle'), 
      TextCellValue('MeetDate'), 
      TextCellValue('Course'), 
      TextCellValue('Distance'), 
      TextCellValue('Stroke'), 
      TextCellValue('TimeMs'), 
      TextCellValue('Club')
    ]);

    for (var event in events) {
      sheet.appendRow([
        TextCellValue(event['firstName'].toString()),
        TextCellValue(event['surname'].toString()),
        TextCellValue(event['dob'].toString()),
        TextCellValue(event['nationality'].toString()),
        TextCellValue(event['meetTitle'].toString()),
        TextCellValue(event['meetDate'].toString()),
        TextCellValue(event['course'].toString()),
        IntCellValue(int.tryParse(event['distance'].toString()) ?? 0),
        TextCellValue(event['stroke'].toString()),
        IntCellValue(int.tryParse(event['timeMs'].toString()) ?? 0),
        TextCellValue(event['club']?.toString() ?? ''),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
  }
}
