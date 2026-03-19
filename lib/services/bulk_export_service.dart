import 'package:csv/csv.dart';
import '../database_helper.dart';

class BulkExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getSwimmerCsvContent(int swimmerId, String course) async {
    final events = await _dbHelper.getEventsForExport(swimmerId, course);
    
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
}
