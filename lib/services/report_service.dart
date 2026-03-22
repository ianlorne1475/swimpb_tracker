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

class ReportService {
  static Future<Uint8List> generateNationalQTReport(Swimmer swimmer, List<SwimEvent> events, List<QualifyingTime> standards) async {
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
        header: (context) => _buildReportHeader('NATIONAL QUALIFICATION REPORT', swimmer, dateStr),
        footer: (context) => _buildReportFooter(),
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
                    _formatTime(qt.timeMs),
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

  static Future<Uint8List> generatePersonalGoalsReport(Swimmer swimmer, List<SwimmerGoal> goals, List<SwimEvent> allEvents) async {
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
        header: (context) => _buildReportHeader('PERSONAL GOALS REPORT', swimmer, dateStr),
        footer: (context) => _buildReportFooter(),
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
                          _buildGoalStep('Current PB', (item['currentPB'] as SwimEvent).formattedTime, PdfColors.grey700),
                          _buildGoalStep('Interim 1', _formatTime(item['interims'][0]), PdfColors.blue300),
                          _buildGoalStep('Interim 2', _formatTime(item['interims'][1]), PdfColors.blue600),
                          _buildGoalStep('TARGET GOAL', (item['goal'] as SwimmerGoal).formattedTime, PdfColors.green700),
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
                    pw.Text('"${_getRandomQuote()}"', 
                      style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 12),
                    pw.Text('Training Suggestions to Reach Your Goals:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ..._getRandomTips(3).map((tip) => _buildBulletPoint(tip)),
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

  static pw.Widget _buildReportHeader(String title, Swimmer swimmer, String dateStr) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('SwimPB Tracker', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(swimmer.fullName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportFooter() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Center(
        child: pw.Text('Copyright @ 2026 trisoftsg. All Rights Reserved.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
    );
  }

  static pw.Widget _buildGoalStep(String label, String time, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text(time, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static pw.Widget _buildProgressionChart(List<SwimEvent> events, int qtMs) {
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
          buildLabel: (num value) => pw.Text(_formatTime(value.toInt()), style: const pw.TextStyle(fontSize: 7)),
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

  static pw.Widget _buildGoalChart(int currentMs, List<int> interims, int goalMs, List<String> dateLabels) {
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
          buildLabel: (num value) => pw.Text(_formatTime(value.toInt()), style: const pw.TextStyle(fontSize: 7)),
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

  static Future<void> generateAndShareReport(
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

  static Future<Uint8List> generatePersonalBestsReport(Swimmer swimmer, List<SwimEvent> events) async {
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
                      pw.Text('PERSONAL BESTS REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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

    return await pdf.save();
  }

  static Future<Uint8List> generateCertificatePdf(Uint8List imageBytes) async {
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

  static Future<void> sharePersonalBestsReport(Uint8List bytes, Swimmer swimmer) async {
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

  static Future<void> shareCertificate(Uint8List imageBytes, Swimmer swimmer, String eventName) async {
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

  static String _getRandomQuote() {
    return _quotes[Random().nextInt(_quotes.length)];
  }

  static List<String> _getRandomTips(int count) {
    final random = Random();
    final selected = <String>[];
    final tipsCopy = List<String>.from(_tips);
    
    for (var i = 0; i < count && tipsCopy.isNotEmpty; i++) {
      final index = random.nextInt(tipsCopy.length);
      selected.add(tipsCopy.removeAt(index));
    }
    return selected;
  }

  static const List<String> _quotes = [
    "Success isn't always about greatness. It's about consistency. Consistent hard work leads to success. Greatness will come.",
    "The only person you should try to be better than is the person you were yesterday.",
    "The only limit to our realization of tomorrow will be our doubts of today.",
    "Don't count the days, make the days count.",
    "Hard work beats talent when talent doesn't work hard.",
    "Success is the sum of small efforts, repeated day in and day out.",
    "The harder the struggle, the more glorious the triumph.",
    "Believe you can and you're halfway there.",
    "Your only competition is the clock and yourself.",
    "Great things never come from comfort zones.",
    "The difference between who you are and who you want to be is what you do.",
    "Don't stop when you're tired. Stop when you're done.",
    "Every champion was once a contender that refused to give up.",
    "Strength doesn't come from what you can do. It comes from overcoming the things you once thought you couldn't.",
    "It's not about being the best. It's about being better than you were yesterday.",
    "Fall seven times, stand up eight.",
    "The secret of getting ahead is getting started.",
    "Don't dream of success. Work for it.",
    "The only way to achieve the impossible is to believe it is possible.",
    "Discipline is doing what needs to be done, even if you don't want to do it.",
  ];

  static const List<String> _tips = [
    "Master Your Technique: Focus on a strong, early vertical forearm catch and a full finish to maximize every stroke.",
    "Build Race Pace Endurance: Incorporate 50m and 100m repeats at your goal pace with short rest intervals.",
    "Optimize Underwaters: Your turns and streamlines are the fastest part of your race. Keep them tight and explosive.",
    "High Elbow Catch: In freestyle, maintain a high elbow during the catch phase to pull more water.",
    "Body Rotation: Use your core to rotate your body in freestyle and backstroke for longer reaches and more power.",
    "Bilateral Breathing: Practice breathing on both sides in freestyle to stay balanced and prevent shoulder injury.",
    "Steady Head Position: In backstroke, keep your head still and eyes up to maintain a straight line and reduce drag.",
    "Narrow Breaststroke Kick: Avoid pushing your knees too far out; a compact, powerful snap is more efficient.",
    "Breaststroke Timing: Don't start your kick until your arms are already extending forward into the streamline.",
    "Butterfly Rhythm: Focus on the 'chest press' and two rhythmic kicks to keep your hips high in the water.",
    "Quiet Entry: Minimize splash on hand entry to reduce turbulence and start your pull sooner.",
    "Full Finish: Ensure your hand pushes all the way past your hip before starting the recovery phase.",
    "Tight Streamline: Overlap your hands and squeeze your ears every time you leave the wall.",
    "Dolphin Kicker Power: Develop your core strength to improve the speed and depth of your underwater kicks.",
    "Fast Turns: Tuck your chin and use your core to flip quickly; don't wait for your feet to hit the wall.",
    "Explosive Starts: Focus on a quick reaction time and a deep, powerful drive off the blocks.",
    "Breathing Control: Work on your lung capacity with hypoxic sets, but always under coach supervision.",
    "Drafting Skills: In practice, learn to stay close to the swimmer ahead to save energy and feel the water.",
    "Stroke Count Awareness: Count your strokes per lap and aim to reduce the number while maintaining speed.",
    "Vertical Kicking: Use vertical kick sets to build leg strength and improve your body position.",
    "Flexibility Matters: Stretch your shoulders and ankles daily to increase your range of motion and efficiency.",
    "Recovery Sets: Don't skip the slow laps; they help flush out lactic acid and maintain your feel for the water.",
    "Hydration: Drink plenty of water throughout the day, not just during practice, to prevent cramps.",
    "Sleep for Performance: Aim for 8-10 hours of sleep to allow your muscles and mind to recover fully.",
    "Post-Practice Nutrition: Consume protein and carbs within 30 minutes of finishing a session to rebuild muscle.",
    "Visualization: Spend 10 minutes a day imagining your perfect race, from the start to the final touch.",
    "Pacing Strategy: Learn to negative split your races—swim the second half faster than the first.",
    "Threshold Training: Push yourself into the 'uncomfortable' zone to increase your aerobic capacity.",
    "Strength Training: Use dryland exercises like planks and pull-ups to build the power needed for explosive swims.",
    "Ankle Mobility: Flexible ankles act like flippers; use a medicine ball or wall stretches to improve them.",
    "Sculling Drills: Use sculling to develop a better 'feel' for the water in all four strokes.",
    "Fist Drill: Try swimming freestyle with closed fists to focus on your forearm's role in the pull.",
    "Catch-up Drill: Hold one arm in front until the recovering arm 'catches up' to improve timing and length.",
    "Finger-tip Drag: Drag your fingertips on the water during freestyle recovery to encourage a high elbow.",
    "One-Arm Drills: Isolate each side to identify and correct imbalances in your pull or rotation.",
    "Kick with a Board: Separate your leg work to build a more consistent and powerful drive.",
    "No-Breather Sprints: Practice short, explosive sprints without breathing to build speed and power.",
    "Vertical Scull: Build shoulder strength and water awareness by sculling while vertical in the deep end.",
    "Reverse Scull: Practice pushing water away from your head to master the 'finish' phase of the stroke.",
    "Side Kicking: Improve your balance and rotation by kicking on your side in freestyle and backstroke.",
    "Hip Awareness: Your power comes from your hips; focus on driving them upward in butterfly and breaststroke.",
    "Relaxed Recovery: Keep your arms and shoulders relaxed during the recovery phase to save energy.",
    "Finger Awareness: Keep your fingers slightly apart or loosely closed for the best water resistance.",
    "Wrist Position: Keep your wrist firm but not stiff during the pull to maintain a strong paddle shape.",
    "Kick Timing in Backstroke: Maintain a steady, 6-beat kick to keep your body high and stable.",
    "Breaststroke Glide: Don't rush; utilize the glide phase to carry your momentum forward.",
    "Butterfly Head Position: Look down, not forward, during the pull to keep your neck relaxed and hips high.",
    "Sprint Starts: Focus on the 'entry' hole; aim to get your whole body through the same small circle in the water.",
    "Wall Awareness: Count your strokes so you know exactly when to start your turn without looking.",
    "Finish Strong: Lung for the wall on the final touch; never glide into the finish.",
    "Consistency: Training twice a week well is better than five times poorly. Show up every day.",
    "Mental Fortitude: When it gets hard, focus on your next breath or your next stroke, not the remaining laps.",
    "Equipment: Use fins or paddles occasionally to feel extra speed and improve your technical awareness.",
    "Snorkel Training: Use a front-facing snorkel to focus entirely on your stroke without the distraction of breathing.",
    "Video Analysis: Ask someone to record you; seeing your stroke is the fastest way to identify mistakes.",
    "Team Spirit: Encourage your lane mates; a positive environment helps everyone swim faster.",
    "Goal Review: Revisit your goals every month and adjust your training focus accordingly.",
    "Listen to Your Coach: They see things you can't; trust their feedback and apply it immediately.",
    "Warm-up Properly: A good warm-up prepares your heart and muscles for the main set intensities.",
    "Cool-down Effectively: Spend time at the end of practice to lower your heart rate and prevent stiffness.",
    "Avoid 'Empty' Laps: Every lap should have a purpose, whether it's speed, technique, or recovery.",
    "Monitor Heart Rate: Learn what different intensities feel like and how to hit your target zones.",
    "Tapering Logic: Trust the process; reducing volume before a big meet allows your body to reach peak power.",
    "Race Prep: Have a routine before your race—stretching, music, or breathing—to stay in the zone.",
    "Swim Meet Nutrition: Eat light, familiar foods between events to keep your energy up without feeling heavy.",
    "Dryland Mobility: Yoga or Pilates can greatly improve your core stability and swimming flexibility.",
    "Core Stability: A strong core prevents your hips from wagging and keeps you laser-straight.",
    "Pull Buoy Efficiency: Use a pull buoy to isolate your arms and work on your distance-per-stroke.",
    "Band Only Pull: Tie your ankles to work on your catch and shoulder power without any leg help.",
    "Progressive Sets: Start at a moderate pace and increase speed with each rep to build finishing power.",
    "Descending Intervals: Aim to do each rep faster than the previous one during a set.",
    "Negative Split Practice: Swim the second half of your sets 2-3 seconds faster than the first half.",
    "Open Water Skills: If you swim in lakes or oceans, practice 'sighting' and navigating without walls.",
    "Bilateral Breathing in Races: Use it to see your competitors on both sides and stay balanced.",
    "Butterfly Kick Coordination: Your first kick starts when your hands enter; the second starts when they finish.",
    "Backstroke Shoulder Roll: Aim to bring your shoulder out of the water on every stroke for more reach.",
    "Breaststroke Knee Position: Keep your knees closer together than your feet to create more power.",
    "Freestyle Head Stability: Your head shouldn't move unless you are breathing; imagine a laser on your cap.",
    "Hand Entry Position: Enter your hands at shoulder width to avoid crossing over and losing power.",
    "Pressure Perception: Focus on feeling the water on your palms and forearms as you pull.",
    "Positive Self-Talk: Replace 'I can't' with 'How can I?' when facing a difficult set.",
    "Active Recovery: On rest days, do a light walk or cycle to keep your blood flowing and muscles loose.",
    "Sun Protection: If training outdoors, use waterproof sunscreen to prevent burns and dehydration.",
    "Goggle Management: Ensure your goggles are tight but comfortable; leaking goggles are a race-day disaster.",
    "Cap Choice: Try different caps (silicone vs. latex) to see what fits best and stays secure.",
    "Race Visualization: Imagine the feel of the water and the sound of the crowd before your start.",
    "Pre-Race Jitters: Use deep belly breathing to calm your nervous system before the whistle blows.",
    "Post-Race Analysis: Win or lose, analyze what went well and what can be improved for next time.",
    "Set Small Milestones: Breaking a big goal into weekly targets makes the journey less daunting.",
    "Enjoy the Process: Swimming is a journey; enjoy the friendships and the struggle as much as the result.",
    "Wall Push-offs: Always push off deep and in a tight streamline; don't take a breath on your first stroke.",
    "Turn Speed: Drive your feet into the wall and explode off as fast as possible.",
    "IM Pacing: Focus on the transition between strokes; don't lose momentum when changing styles.",
    "Butterfly Recovery: Keep your arms low and wide to save energy and stay aerodynamic.",
    "Breaststroke Kick Power: Think of your feet as paddles; push the water straight back, not down.",
    "Backstroke Exit: Lead with your thumb out and pinky in to minimize drag during recovery.",
    "Freestyle Kick Amplitude: Keep your kick small and fast; don't let your feet leave the water too much.",
    "Shoulder Health: Use resistance bands for 'internal/external rotation' exercises to prevent injury.",
    "Consistency is King: Successful swimmers aren't born; they are forged over thousands of early mornings.",
    "Believe in Your Training: On race day, trust that you've done the work. Now go out and show it!",
  ];
}
