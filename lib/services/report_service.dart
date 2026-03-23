import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../models/swimmer.dart';
import '../models/qualifying_time.dart';
import '../models/goal.dart';
import '../utils/time_utils.dart';
import '../data/report_content.dart';
import 'report_base.dart';

class ReportService with BaseReport {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<Uint8List> generateNationalQTReport(Swimmer swimmer, List<SwimEvent> events, List<QualifyingTime> standards) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    // Group standards by event (distance/stroke) for easy lookup
    final standardsMap = <String, QualifyingTime>{};
    for (var s in standards) {
      if (s.course == 'LCM') { // National standards usually LCM
        standardsMap['${s.distance}-${s.stroke}'.toLowerCase()] = s;
      }
    }

    // Find qualifying PBs
    final qualifyingEvents = <Map<String, dynamic>>[];
    final pbsMap = <String, SwimEvent>{};
    for (var e in events) {
      if (e.course != 'LCM') continue;
      final key = "${e.distance}-${e.stroke}".toLowerCase();
      if (!pbsMap.containsKey(key) || e.timeMs < pbsMap[key]!.timeMs) {
        pbsMap[key] = e;
      }
    }

    for (var key in pbsMap.keys) {
      final pb = pbsMap[key]!;
      final standard = standardsMap[key];
      if (standard != null && pb.timeMs <= standard.timeMs) {
        // Find progression for this event
        final progression = events
            .where((e) => e.distance == pb.distance && e.stroke == pb.stroke && e.course == 'LCM')
            .toList()
          ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
        
        qualifyingEvents.add({
          'pb': pb,
          'standard': standard,
          'progression': progression,
        });
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => buildReportHeader('NATIONAL QUALIFICATION REPORT', swimmer, dateStr),
        footer: (context) => buildReportFooter(),
        build: (pw.Context context) {
          return [
            if (qualifyingEvents.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 100),
                child: pw.Center(child: pw.Text('No national qualifying times met yet. Keep training!', style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic))),
              )
            else ...[
              pw.Text('Qualifying Standards Met (SNAG 2026)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Event', 'Your PB', 'National QT', 'Status'],
                data: qualifyingEvents.map((item) {
                  final pb = item['pb'] as SwimEvent;
                  final qt = item['standard'] as QualifyingTime;
                  return [
                    '${pb.distance}m ${pb.stroke}',
                    pb.formattedTime,
                    TimeUtils.formatTime(qt.timeMs),
                    'QUALIFIED',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 30),
              
              for (var item in qualifyingEvents) ...[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${(item['pb'] as SwimEvent).distance}m ${(item['pb'] as SwimEvent).stroke} Progression', 
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      height: 150,
                      child: _buildProgressionChart(
                        item['progression'] as List<SwimEvent>, 
                        (item['standard'] as QualifyingTime).timeMs
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColors.grey300),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ],
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<Uint8List> generatePersonalGoalsReport(Swimmer swimmer, List<SwimmerGoal> goals, List<SwimEvent> allEvents) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    final goalData = <Map<String, dynamic>>[];
    for (var goal in goals) {
      // Find current PB for this event
      final pbEvents = allEvents.where((e) => 
        e.distance == goal.distance && 
        e.stroke == goal.stroke && 
        e.course == goal.course).toList();
      
      if (pbEvents.isEmpty) continue;
      
      final currentPB = pbEvents.reduce((a, b) => a.timeMs < b.timeMs ? a : b);
      
      // Calculate interim goals (3 steps)
      final totalDiff = currentPB.timeMs - goal.timeMs;
      final step = totalDiff / 3;
      final interims = [
        (currentPB.timeMs - step).toInt(),
        (currentPB.timeMs - 2 * step).toInt(),
      ];

      // Interpolate dates if targetDate is set
      final List<String> dateLabels = ['Now', 'Step 1', 'Step 2', 'Target'];
      if (goal.targetDate != null) {
        try {
          final startDate = currentPB.date != null ? DateTime.parse(currentPB.date!) : DateTime.now();
          final endDate = goal.targetDate!;
          final totalDays = endDate.difference(startDate).inDays;
          if (totalDays > 0) {
            final dayStep = totalDays / 3;
            dateLabels[0] = DateFormat('d MMM yy').format(startDate);
            dateLabels[1] = DateFormat('d MMM yy').format(startDate.add(Duration(days: dayStep.toInt())));
            dateLabels[2] = DateFormat('d MMM yy').format(startDate.add(Duration(days: (dayStep * 2).toInt())));
            dateLabels[3] = DateFormat('d MMM yy').format(endDate);
          }
        } catch (_) {}
      }

      goalData.add({
        'goal': goal,
        'currentPB': currentPB,
        'interims': interims,
        'dateLabels': dateLabels,
      });
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => buildReportHeader('PERSONAL GOALS REPORT', swimmer, dateStr),
        footer: (context) => buildReportFooter(),
        build: (pw.Context context) {
          return [
            if (goalData.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 100),
                child: pw.Center(child: pw.Text('No personal goals set yet.', style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic))),
              )
            else ...[
              pw.Text('Active Goals Path', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              for (var item in goalData) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${(item['goal'] as SwimmerGoal).distance}m ${(item['goal'] as SwimmerGoal).stroke} (${(item['goal'] as SwimmerGoal).course})', 
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          buildGoalStep('Current PB', (item['currentPB'] as SwimEvent).formattedTime, PdfColors.grey700),
                          buildGoalStep('Interim 1', TimeUtils.formatTime(item['interims'][0]), PdfColors.blue300),
                          buildGoalStep('Interim 2', TimeUtils.formatTime(item['interims'][1]), PdfColors.blue600),
                          buildGoalStep('TARGET GOAL', (item['goal'] as SwimmerGoal).formattedTime, PdfColors.green700),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                      pw.Container(
                        height: 120,
                        child: _buildGoalChart(
                          (item['currentPB'] as SwimEvent).timeMs,
                          item['interims'] as List<int>,
                          (item['goal'] as SwimmerGoal).timeMs,
                          item['dateLabels'] as List<String>,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('COACH\'S CORNER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 8),
                    pw.Text('"${ReportContent.getRandomQuote()}"', 
                      style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 12),
                    pw.Text('Training Suggestions to Reach Your Goals:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ...ReportContent.getRandomTips(3).map((tip) => buildBulletPoint(tip)),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildProgressionChart(List<SwimEvent> events, int qtMs) {
    final dataPoints = <pw.PointChartValue>[];
    for (var i = 0; i < events.length; i++) {
      dataPoints.add(pw.PointChartValue(i.toDouble(), events[i].timeMs.toDouble()));
    }

    // Determine Y axis range
    final times = events.map((e) => e.timeMs).toList()..add(qtMs);
    final minTime = times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.reduce((a, b) => a > b ? a : b);
    final padding = (maxTime - minTime) * 0.1;

    // Format X axis labels (Dates)
    final xAxisLabels = events.map((e) {
      if (e.date == null) return '';
      try {
        final date = DateTime.parse(e.date!);
        return DateFormat('dd-MM-yyyy').format(date);
      } catch (_) {
        return '';
      }
    }).toList();

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(xAxisLabels, textStyle: const pw.TextStyle(fontSize: 7)),
        yAxis: pw.FixedAxis(
          [minTime - padding, (minTime + maxTime) / 2, maxTime + padding],
          buildLabel: (num value) => pw.Text(TimeUtils.formatTime(value.toInt()), style: const pw.TextStyle(fontSize: 7)),
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Performance',
          color: PdfColors.blue,
          data: dataPoints,
          isCurved: true,
        ),
        pw.LineDataSet(
          legend: 'Qualification Time',
          color: PdfColors.red,
          drawPoints: false,
          lineWidth: 1,
          data: [
            pw.PointChartValue(0, qtMs.toDouble()),
            pw.PointChartValue((events.length - 1).toDouble(), qtMs.toDouble()),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildGoalChart(int currentMs, List<int> interims, int goalMs, List<String> dateLabels) {
    final dataPoints = [
      pw.PointChartValue(0, currentMs.toDouble()),
      pw.PointChartValue(1, interims[0].toDouble()),
      pw.PointChartValue(2, interims[1].toDouble()),
      pw.PointChartValue(3, goalMs.toDouble()),
    ];

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(dateLabels, textStyle: const pw.TextStyle(fontSize: 6)),
        yAxis: pw.FixedAxis(
          [goalMs.toDouble(), (currentMs + goalMs) / 2, currentMs.toDouble()],
          buildLabel: (num value) => pw.Text(TimeUtils.formatTime(value.toInt()), style: const pw.TextStyle(fontSize: 7)),
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Path to Goal',
          color: PdfColors.blue,
          data: dataPoints,
          isCurved: true,
          drawPoints: true,
        ),
      ],
    );
  }

  Future<void> generateAndShareReport(
    Swimmer swimmer, 
    String reportType, 
    Future<Uint8List> Function() generator
  ) async {
    final bytes = await generator();
    final output = await getTemporaryDirectory();
    final dateFileStr = DateFormat('ddMMyyyy').format(DateTime.now());
    final fileName = "${swimmer.firstName}_${swimmer.surname}_${dateFileStr}_$reportType.pdf".toLowerCase().replaceAll(' ', '_');
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${reportType.replaceAll("_", " ").toUpperCase()} for ${swimmer.fullName}',
    );
  }

  Future<Uint8List> generatePersonalBestsReport(Swimmer swimmer, List<SwimEvent> events) async {
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
                      pw.Text('PERSONAL BESTS REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
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
              cellHeight: 20, 
              cellStyle: const pw.TextStyle(fontSize: 8.5), 
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
                  buildStatRow('Total Races Completed', events.length.toString()),
                  buildStatRow('Short Course (SCM) Meets', events.where((e) => e.course == 'SCM').map((e) => e.meetId).toSet().length.toString()),
                  buildStatRow('Long Course (LCM) Meets', events.where((e) => e.course == 'LCM').map((e) => e.meetId).toSet().length.toString()),
                  buildStatRow('Swimming Career Length (so far)', _calculateCareerLength(events)),
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
            
            buildReportFooter(),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<Uint8List> generateCertificatePdf(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image),
          );
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> sharePersonalBestsReport(Uint8List bytes, Swimmer swimmer) async {
    final output = await getTemporaryDirectory();
    final dateFileStr = DateFormat('ddMMyyyy').format(DateTime.now());
    final fileName = "${swimmer.firstName}_${swimmer.surname}_${dateFileStr}_personal_bests_report.pdf".toLowerCase().replaceAll(' ', '_');
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Personal Bests Report for ${swimmer.fullName}',
    );
  }

  Future<void> shareCertificate(Uint8List imageBytes, Swimmer swimmer, String eventName) async {
    final output = await getTemporaryDirectory();
    final dateFileStr = DateFormat('ddMMyyyy').format(DateTime.now());
    final fileName = "${swimmer.firstName}_${swimmer.surname}_${dateFileStr}_pb_certificate_${eventName.toLowerCase().replaceAll(' ', '_')}.png";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(imageBytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Check out this new PB from ${swimmer.fullName}! 🏊‍♂️🏆',
    );
  }

  String _calculateCareerLength(List<SwimEvent> events) {
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

  int _getStrokeOrder(String stroke) {
    stroke = stroke.toLowerCase();
    if (stroke.contains('fly')) return 0;
    if (stroke.contains('back')) return 1;
    if (stroke.contains('breast')) return 2;
    if (stroke.contains('free')) return 3;
    if (stroke.contains('medley') || stroke == 'im') return 4;
    return 5;
  }

  Map<String, int> _calculateStrokeBreakdown(List<SwimEvent> events) {
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
}
