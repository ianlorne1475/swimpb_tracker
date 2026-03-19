import 'package:flutter/material.dart';
import '../../database_helper.dart';
import '../../models/event.dart';
import '../../models/swimmer.dart';
import '../../models/qualifying_time.dart';
import '../../widgets/pb_card.dart';
import '../../theme/app_theme.dart';

class PersonalBestsTab extends StatelessWidget {
  final int swimmerId;
  const PersonalBestsTab({super.key, required this.swimmerId});

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper();

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadData(dbHelper),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data!['pbs'] as List<SwimEvent>).isEmpty) {
          return const Center(child: Text('No Personal Bests recorded yet.'));
        }

        final allEvents = snapshot.data!['pbs'] as List<SwimEvent>;
        final standards = snapshot.data!['standards'] as List<QualifyingTime>;
        
        // Group by (distance, stroke) to align kurses
        final eventTypes = <String>{};
        for (var e in allEvents) {
          eventTypes.add('${e.distance}-${e.stroke}');
        }

        final sortedTypes = eventTypes.toList()..sort((a, b) {
          final partsA = a.split('-');
          final partsB = b.split('-');
          
          final distA = int.parse(partsA[0]);
          final distB = int.parse(partsB[0]);
          final strokeA = partsA[1];
          final strokeB = partsB[1];

          final strokeOrder = {'Butterfly': 0, 'Backstroke': 1, 'Breaststroke': 2, 'Freestyle': 3, 'IM': 4};
          final orderA = strokeOrder[strokeA] ?? 99;
          final orderB = strokeOrder[strokeB] ?? 99;

          if (orderA != orderB) return orderA.compareTo(orderB);
          return distA.compareTo(distB);
        });

        final eventRows = <Widget>[];
        
        // Add Headers row
        eventRows.add(
          Row(
            children: [
              Expanded(child: _buildHeader(context, 'SHORT COURSE', AppColors.primary, '25M')),
              Expanded(child: _buildHeader(context, 'LONG COURSE', AppColors.accent, '50M')),
            ],
          ),
        );

        for (final type in sortedTypes) {
          final parts = type.split('-');
          final dist = int.parse(parts[0]);
          final stroke = parts[1];

          final scmEvent = allEvents.cast<SwimEvent?>().firstWhere(
            (e) => e?.course == 'SCM' && e?.distance == dist && e?.stroke == stroke,
            orElse: () => null,
          );
          
          final lcmEvent = allEvents.cast<SwimEvent?>().firstWhere(
            (e) => e?.course == 'LCM' && e?.distance == dist && e?.stroke == stroke,
            orElse: () => null,
          );

          Widget scmCard = scmEvent != null 
              ? PBCard(
                  event: scmEvent, 
                  metStandards: standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'SCM' && scmEvent.timeMs <= s.timeMs).toList(), 
                  targetStandard: standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'SCM').isNotEmpty 
                      ? standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'SCM').first 
                      : null
                )
              : const SizedBox(height: 186); // Card (170) + margins (8+8)

          Widget lcmCard = lcmEvent != null 
              ? PBCard(
                  event: lcmEvent, 
                  metStandards: standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'LCM' && lcmEvent.timeMs <= s.timeMs).toList(),
                  targetStandard: standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'LCM').isNotEmpty 
                      ? standards.where((s) => s.distance == dist && s.stroke == stroke && s.course == 'LCM').first 
                      : null
                )
              : const SizedBox(height: 186);

          eventRows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: scmCard),
                Expanded(child: lcmCard),
              ],
            ),
          );
        }
        
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...eventRows,
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadData(DatabaseHelper dbHelper) async {
    final pbs = await dbHelper.getPBsBySwimmer(swimmerId);
    final swimmers = await dbHelper.getSwimmers();
    final swimmer = swimmers.firstWhere((s) => s.id == swimmerId);
    final age = swimmer.calculateAgeAtEndYear();
    final standards = await dbHelper.getStandardsForSwimmer(age, swimmer.gender);
    
    return {
      'pbs': pbs,
      'standards': standards,
    };
  }

  Widget _buildHeader(BuildContext context, String title, Color dotColor, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: dotColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: dotColor.withOpacity(0.2)),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

