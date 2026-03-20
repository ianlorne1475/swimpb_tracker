import 'package:flutter/material.dart';
import '../../database_helper.dart';
import '../../models/event.dart';
import '../../models/qualifying_time.dart';
import '../../widgets/pb_card.dart';
import '../../theme/app_theme.dart';

class RecentBestsTab extends StatefulWidget {
  final int swimmerId;
  const RecentBestsTab({super.key, required this.swimmerId});

  @override
  State<RecentBestsTab> createState() => _RecentBestsTabState();
}

class _RecentBestsTabState extends State<RecentBestsTab> {
  int _distance = 50;
  String _stroke = 'Butterfly';
  String _course = 'SCM';

  List<int> _getValidDistances() {
    if (_stroke == 'Freestyle') {
      return [50, 100, 200, 400, 800, 1500];
    } else if (_stroke == 'IM') {
      return _course == 'SCM' ? [100, 200] : [200, 400];
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

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper();
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDropdown<int>(
                value: _distance,
                items: _getValidDistances().map((d) => DropdownMenuItem(value: d, child: Text('${d}m'))).toList(),
                onChanged: (v) => setState(() => _distance = v!),
              ),
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
              _buildDropdown<String>(
                value: _course,
                items: ['SCM', 'LCM'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() {
                  _course = v!;
                  _validateDistance();
                }),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _loadData(dbHelper),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || (snapshot.data!['events'] as List<SwimEvent>).isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'NO TIMES FOUND FOR SELECTION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1),
                      ),
                    ],
                  ),
                );
              }

              final events = snapshot.data!['events'] as List<SwimEvent>;
              final standards = snapshot.data!['standards'] as List<QualifyingTime>;
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8), // horizontal padding handled by PBCard internal margin
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final metStandards = standards.where((s) => 
                    s.distance == event.distance && 
                    s.stroke == event.stroke && 
                    s.course == event.course && 
                    event.timeMs <= s.timeMs
                  ).toList();
                  
                  return PBCard(
                    event: event, 
                    metStandards: metStandards,
                    rank: index + 1,
                    showQTLabel: true,
                  );
                },
              );
            },
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

  Future<Map<String, dynamic>> _loadData(DatabaseHelper dbHelper) async {
    final events = await dbHelper.getRecentBests(widget.swimmerId, _distance, _stroke, _course);
    final swimmers = await dbHelper.getSwimmers();
    final swimmer = swimmers.firstWhere((s) => s.id == widget.swimmerId);
    final age = swimmer.calculateAgeAtEndYear();
    final standards = await dbHelper.getStandardsForSwimmer(age, swimmer.gender);

    return {
      'events': events,
      'standards': standards,
    };
  }
}

