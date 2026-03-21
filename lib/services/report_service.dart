import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../models/swimmer.dart';

class ReportService {
  static Future<void> generatePerformanceReport(Swimmer swimmer, List<SwimEvent> events) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    // Sort events by date descending
    events.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PERFORMANCE REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('SwimPB Tracker', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(swimmer.fullName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Text('Summary of Personal Bests', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            // PB Table
            pw.TableHelper.fromTextArray(
              headers: ['Event', 'Course', 'Time', 'Meet', 'Date'],
              data: (() {
                // Get one best event for each distance/stroke/course combination
                final pbsMap = <String, SwimEvent>{};
                for (var e in events) {
                  final key = "${e.distance}-${e.stroke}-${e.course}".toLowerCase();
                  if (!pbsMap.containsKey(key) || e.timeMs < pbsMap[key]!.timeMs) {
                    pbsMap[key] = e;
                  }
                }
                
                final sortedPBs = pbsMap.values.toList()
                  ..sort((a, b) {
                    // Sort by stroke order
                    final sComp = _getStrokeOrder(a.stroke).compareTo(_getStrokeOrder(b.stroke));
                    if (sComp != 0) return sComp;
                    // Then by distance
                    return a.distance.compareTo(b.distance);
                  });

                return sortedPBs.map((e) => [
                  '${e.distance}m ${e.stroke}',
                  e.course ?? '',
                  e.formattedTime,
                  e.meetTitle ?? 'Unknown',
                  e.formattedDate,
                ]).toList();
              })(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 20, // Reduced from 25
              cellStyle: const pw.TextStyle(fontSize: 8.5), // Reduced from 9
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
              },
            ),
            
            pw.SizedBox(height: 25),
            pw.Text('Key Facts and Statistics', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Total Races Completed', events.length.toString()),
                  _buildStatRow('Short Course (SCM) Meets', events.where((e) => e.course == 'SCM').map((e) => e.meetId).toSet().length.toString()),
                  _buildStatRow('Long Course (LCM) Meets', events.where((e) => e.course == 'LCM').map((e) => e.meetId).toSet().length.toString()),
                  _buildStatRow('Swimming Career Length (so far)', _calculateCareerLength(events)),
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 8),
                  pw.Text('Stroke Race Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: _calculateStrokeBreakdown(events).entries.map((entry) {
                      return pw.Text('${entry.key}: ${entry.value}', style: const pw.TextStyle(fontSize: 9));
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 40),
              child: pw.Center(
                child: pw.Text('Copyright @ 2026 trisoftsg. All Rights Reserved.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final dateFileStr = DateFormat('ddMMyyyy').format(DateTime.now());
    final fileName = "${swimmer.firstName}_${swimmer.surname}_${dateFileStr}_performance_report.pdf".toLowerCase().replaceAll(' ', '_');
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Performance Report for ${swimmer.fullName}',
    );
  }

  static pw.Widget _buildStatRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static String _calculateCareerLength(List<SwimEvent> events) {
    final dates = events
        .map((e) => e.date != null ? DateTime.tryParse(e.date!) : null)
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return 'N/A';
    
    final start = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final end = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final diff = end.difference(start);
    
    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    
    if (years > 0) {
      return '$years Year${years > 1 ? "s" : ""}, $months Month${months != 1 ? "s" : ""}';
    } else {
      return '$months Month${months != 1 ? "s" : ""}';
    }
  }

  static int _getStrokeOrder(String stroke) {
    stroke = stroke.toLowerCase();
    if (stroke.contains('fly')) return 0;
    if (stroke.contains('back')) return 1;
    if (stroke.contains('breast')) return 2;
    if (stroke.contains('free')) return 3;
    if (stroke.contains('medley') || stroke == 'im') return 4;
    return 5;
  }

  static Map<String, int> _calculateStrokeBreakdown(List<SwimEvent> events) {
    final Map<String, int> counts = {};
    for (var e in events) {
      counts[e.stroke] = (counts[e.stroke] ?? 0) + 1;
    }
    
    // Sort keys based on stroke order
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => _getStrokeOrder(a).compareTo(_getStrokeOrder(b)));
    
    final Map<String, int> sortedCounts = {};
    for (var key in sortedKeys) {
      sortedCounts[key] = counts[key]!;
    }
    return sortedCounts;
  }

  static Future<void> shareCertificate(Uint8List imageBytes, String swimmerName) async {
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/pb_certificate.png");
    await file.writeAsBytes(imageBytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Check out this new PB from $swimmerName! 🏊‍♂️🏆',
    );
  }

  static String _formatTime(int timeMs) {
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
}
