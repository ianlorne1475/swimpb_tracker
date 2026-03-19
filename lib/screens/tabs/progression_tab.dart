import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database_helper.dart';
import '../../models/event.dart';
import '../../models/swimmer.dart';
import '../../models/qualifying_time.dart';
import '../../theme/app_theme.dart';

class ProgressionTab extends StatefulWidget {
  final int swimmerId;
  const ProgressionTab({super.key, required this.swimmerId});

  @override
  State<ProgressionTab> createState() => _ProgressionTabState();
}

class _ProgressionTabState extends State<ProgressionTab> {
  int _distance = 50;
  String _stroke = 'Butterfly';
  String _course = 'SCM';
  String _timeframe = 'All Time';

  List<int> _getValidDistances() {
    if (_stroke == 'Freestyle') {
      return [50, 100, 200, 400, 800, 1500];
    } else if (_stroke == 'IM') {
      return _course == 'SCM' ? [100, 200, 400] : [200, 400];
    } else {
      return [50, 100, 200];
    }
  }

  void _validateDistance() {
    final validDistances = _getValidDistances();
    if (!validDistances.contains(_distance)) {
      _distance = validDistances.first;
    }
  }

  DateTime? _getSinceDate() {
    final now = DateTime.now();
    switch (_timeframe) {
      case '6 Months':
        return DateTime(now.year, now.month - 6, now.day);
      case '1 Year':
        return DateTime(now.year - 1, now.month, now.day);
      case '2 Years':
        return DateTime(now.year - 2, now.month, now.day);
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final dbHelper = DatabaseHelper();
    final swimmers = await dbHelper.getSwimmers();
    final swimmer = swimmers.firstWhere((s) => s.id == widget.swimmerId);
    
    final events = await dbHelper.getProgression(
      widget.swimmerId, 
      _distance, 
      _stroke, 
      _course,
      sinceDate: _getSinceDate(),
    );

    final qt = await dbHelper.getQualifyingTimeForEvent(
      _distance, 
      _stroke, 
      swimmer.gender, 
      swimmer.calculateAgeAtEndYear(), 
      _course
    );

    return {
      'events': events,
      'qt': qt,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Selectors
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.lightBorder.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown<int>(
                  value: _distance,
                  items: _getValidDistances().map((d) => DropdownMenuItem(value: d, child: Text('${d}m'))).toList(),
                  onChanged: (v) => setState(() => _distance = v!),
                ),
                const SizedBox(width: 16),
                _buildDropdown<String>(
                  value: _stroke,
                  items: ['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _stroke = v!;
                    _validateDistance();
                  }),
                ),
                const SizedBox(width: 16),
                _buildDropdown<String>(
                  value: _course,
                  items: ['SCM', 'LCM'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() {
                    _course = v!;
                    _validateDistance();
                  }),
                ),
                const SizedBox(width: 16),
                _buildDropdown<String>(
                  value: _timeframe,
                  items: ['6 Months', '1 Year', '2 Years', 'All Time']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _timeframe = v!),
                ),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final events = snapshot.data?['events'] as List<SwimEvent>?;
                final qt = snapshot.data?['qt'] as QualifyingTime?;

                if (events == null || events.length < 2) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'ADD 2+ RESULTS FOR PROGRESSION',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1),
                        ),
                      ],
                    ),
                  );
                }

                final List<FlSpot> spots = [];
                double minY = double.infinity;
                double maxY = double.negativeInfinity;

                for (int i = 0; i < events.length; i++) {
                  final time = events[i].timeMs.toDouble();
                  spots.add(FlSpot(i.toDouble(), time));
                  if (time < minY) minY = time;
                  if (time > maxY) maxY = time;
                }

                if (qt != null) {
                  if (qt.timeMs < minY) minY = qt.timeMs.toDouble();
                  if (qt.timeMs > maxY) maxY = qt.timeMs.toDouble();
                }

                // Add padding
                double range = maxY - minY;
                if (range == 0) range = 1000;
                minY -= range * 0.2;
                maxY += range * 0.2;

                return Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppColors.border : AppColors.lightBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 32.0, left: 16.0, right: 16.0),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: isDark ? AppColors.surface : Colors.white,
                              tooltipRoundedRadius: 8,
                              tooltipBorder: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final event = events[spot.x.toInt()];
                                   return LineTooltipItem(
                                    '${event.formattedTime}\n',
                                    TextStyle(
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      if (event.meetTitle != null)
                                        TextSpan(
                                          text: '${event.meetTitle}\n',
                                          style: TextStyle(
                                            color: isDark ? AppColors.primary : AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      TextSpan(
                                        text: event.formattedDate,
                                        style: TextStyle(
                                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              if (qt != null)
                                HorizontalLine(
                                  y: qt.timeMs.toDouble(),
                                  color: AppColors.accent.withOpacity(0.8),
                                  strokeWidth: 2,
                                  dashArray: [8, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(right: 5, bottom: 5),
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                    labelResolver: (line) {
                                      final duration = Duration(milliseconds: qt.timeMs);
                                      final minutes = duration.inMinutes;
                                      final seconds = duration.inSeconds % 60;
                                      final hundredths = (qt.timeMs % 1000) ~/ 10;
                                      
                                      String formatted;
                                      if (minutes > 0) {
                                        formatted = '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
                                      } else {
                                        formatted = '$seconds.${hundredths.toString().padLeft(2, '0')}';
                                      }
                                      return 'QUALIFIED: $formatted';
                                    },
                                  ),
                                ),
                            ],
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: isDark ? AppColors.border.withOpacity(0.3) : AppColors.lightBorder.withOpacity(0.3),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: isDark ? AppColors.border.withOpacity(0.3) : AppColors.lightBorder.withOpacity(0.3),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: const FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: AppColors.primary,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 5,
                                  color: Colors.white,
                                  strokeWidth: 3,
                                  strokeColor: AppColors.primary,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.3),
                                    AppColors.primary.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.primary),
        dropdownColor: isDark ? AppColors.surface : Colors.white,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}

