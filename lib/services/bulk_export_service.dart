import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../database_helper.dart';

class BulkExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getSwimmerCsvContent(int swimmerId) async {
    final List<Map<String, dynamic>> events = await _dbHelper.getEventsForExport(swimmerId);
    final List<Map<String, dynamic>> goals = await _dbHelper.getGoalsForExport(swimmerId);
    final allData = [...events, ...goals];
    
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
      'Club',
      'DataType',
      'PhotoFile'
    ]);

    for (var data in allData) {
      rows.add([
        data['firstName'],
        data['surname'],
        data['dob'],
        data['nationality'],
        data['meetTitle'],
        data['meetDate'],
        data['course'],
        data['distance'],
        data['stroke'],
        data['timeMs'],
        data['club'] ?? '',
        data['dataType'] ?? 'Result',
        _getPhotoFileName(data),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<Uint8List?> getSwimmerXlsxBytes(int swimmerId) async {
    final List<Map<String, dynamic>> events = await _dbHelper.getEventsForExport(swimmerId);
    final List<Map<String, dynamic>> goals = await _dbHelper.getGoalsForExport(swimmerId);
    final allData = [...events, ...goals];

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
      TextCellValue('Club'),
      TextCellValue('DataType'),
      TextCellValue('PhotoFile')
    ]);

    for (var data in allData) {
      sheet.appendRow([
        TextCellValue(data['firstName']?.toString() ?? ''),
        TextCellValue(data['surname']?.toString() ?? ''),
        TextCellValue(data['dob']?.toString() ?? ''),
        TextCellValue(data['nationality']?.toString() ?? ''),
        TextCellValue(data['meetTitle']?.toString() ?? ''),
        TextCellValue(data['meetDate']?.toString() ?? ''),
        TextCellValue(data['course']?.toString() ?? ''),
        IntCellValue(int.tryParse(data['distance']?.toString() ?? '0') ?? 0),
        TextCellValue(data['stroke']?.toString() ?? ''),
        IntCellValue(int.tryParse(data['timeMs']?.toString() ?? '0') ?? 0),
        TextCellValue(data['club']?.toString() ?? ''),
        TextCellValue(data['dataType']?.toString() ?? 'Result'),
        TextCellValue(_getPhotoFileName(data)),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List?> getTeamXlsxBytes() async {
    final swimmers = await _dbHelper.getSwimmers();
    var excel = Excel.createExcel();
    
    // Remove default sheet
    String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    bool addedAny = false;

    for (var swimmer in swimmers) {
      final List<Map<String, dynamic>> events = await _dbHelper.getEventsForExport(swimmer.id!);
      final List<Map<String, dynamic>> goals = await _dbHelper.getGoalsForExport(swimmer.id!);
      final allData = [...events, ...goals];
      
      if (allData.isEmpty) continue;
      
      String sheetName = swimmer.fullName;
      // Excel sheet names have a 31 char limit and some invalid chars
      sheetName = sheetName.replaceAll(RegExp(r'[\\/?*\[\]]'), '_');
      if (sheetName.length > 31) sheetName = sheetName.substring(0, 31);
      
      var sheet = excel[sheetName];
      addedAny = true;
      
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
        TextCellValue('Club'),
        TextCellValue('DataType'),
        TextCellValue('PhotoFile')
      ]);

      for (var data in allData) {
        sheet.appendRow([
          TextCellValue(data['firstName']?.toString() ?? ''),
          TextCellValue(data['surname']?.toString() ?? ''),
          TextCellValue(data['dob']?.toString() ?? ''),
          TextCellValue(data['nationality']?.toString() ?? ''),
          TextCellValue(data['meetTitle']?.toString() ?? ''),
          TextCellValue(data['meetDate']?.toString() ?? ''),
          TextCellValue(data['course']?.toString() ?? ''),
          IntCellValue(int.tryParse(data['distance']?.toString() ?? '0') ?? 0),
          TextCellValue(data['stroke']?.toString() ?? ''),
          IntCellValue(int.tryParse(data['timeMs']?.toString() ?? '0') ?? 0),
          TextCellValue(data['club']?.toString() ?? ''),
          TextCellValue(data['dataType']?.toString() ?? 'Result'),
          TextCellValue(_getPhotoFileName(data)),
        ]);
      }
    }
    
    if (!addedAny) return null;

    // Delete default sheet if we added others
    if (excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  String _getPhotoFileName(Map<String, dynamic> data) {
    if (data['photoPath'] == null) return '';
    final ext = path.extension(data['photoPath'].toString());
    final fullName = '${data['firstName']}_${data['surname']}'.replaceAll(" ", "_");
    return '${fullName}${ext}';
  }

  Future<Map<String, Uint8List>> getSwimmerFullExport(int swimmerId) async {
    final Map<String, Uint8List> files = {};
    final swimmer = (await _dbHelper.getSwimmers()).firstWhere((s) => s.id == swimmerId);
    
    final xlsx = await getSwimmerXlsxBytes(swimmerId);
    if (xlsx != null) {
      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
      files['${swimmer.firstName}_${swimmer.surname}_$dateStr.xlsx'] = xlsx;
    }

    if (swimmer.photoPath != null) {
      final photoFile = File(swimmer.photoPath!);
      if (await photoFile.exists()) {
        final bytes = await photoFile.readAsBytes();
        final photoName = _getPhotoFileName(swimmer.toMap());
        files[photoName] = bytes;
      }
    }
    return files;
  }

  Future<Map<String, Uint8List>> getTeamFullExport() async {
    final Map<String, Uint8List> files = {};
    final swimmers = await _dbHelper.getSwimmers();
    
    final xlsx = await getTeamXlsxBytes();
    if (xlsx != null) {
      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
      files['multiple_swimmers_$dateStr.xlsx'] = xlsx;
    }

    for (var swimmer in swimmers) {
      if (swimmer.photoPath != null) {
        final photoFile = File(swimmer.photoPath!);
        if (await photoFile.exists()) {
          final bytes = await photoFile.readAsBytes();
          final photoName = _getPhotoFileName(swimmer.toMap());
          files['photos/$photoName'] = bytes;
        }
      }
    }
    return files;
  }
}
