import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';
import '../../models/meet.dart';
import '../../models/event.dart';

import '../../theme/app_theme.dart';

class MeetsTab extends StatelessWidget {
  final int swimmerId;
  const MeetsTab({super.key, required this.swimmerId});

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<SwimMeet>>(
      future: dbHelper.getMeetsBySwimmer(swimmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'NO MEETS RECORDED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2),
                ),
              ],
            ),
          );
        }

        final meets = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: meets.length,
          itemBuilder: (context, index) {
            final meet = meets[index];
            final color = meet.course == 'SCM' ? AppColors.primary : AppColors.accent;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.border : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                backgroundColor: isDark ? AppColors.surface : Colors.white,
                collapsedBackgroundColor: isDark ? AppColors.surface : Colors.white,
                title: Text(
                  meet.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(meet.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        meet.course,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  FutureBuilder<List<SwimEvent>>(
                    future: dbHelper.getEventsByMeet(meet.id!, swimmerId),
                    builder: (context, eventSnapshot) {
                      if (eventSnapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (!eventSnapshot.hasData || eventSnapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No events found'),
                        );
                      }
                      
                      final events = eventSnapshot.data!;
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.background.withOpacity(0.5) : AppColors.lightBackground.withOpacity(0.5),
                        ),
                        child: Column(
                          children: events.map((event) => ListTile(
                            title: Text(
                              '${event.distance}m ${event.stroke}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            trailing: Text(
                              event.formattedTime,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            dense: true,
                          )).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
