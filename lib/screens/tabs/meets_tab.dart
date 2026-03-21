import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';
import '../../models/meet.dart';
import '../../models/event.dart';

import '../../theme/app_theme.dart';

class MeetsTab extends StatefulWidget {
  final int swimmerId;
  const MeetsTab({super.key, required this.swimmerId});

  @override
  State<MeetsTab> createState() => _MeetsTabState();
}

class _MeetsTabState extends State<MeetsTab> {
  final _dbHelper = DatabaseHelper();
  late Future<List<SwimMeet>> _meetsFuture;

  @override
  void initState() {
    super.initState();
    _refreshMeets();
  }

  @override
  void didUpdateWidget(MeetsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.swimmerId != widget.swimmerId) {
      _refreshMeets();
    }
  }

  void _refreshMeets() {
    setState(() {
      _meetsFuture = _dbHelper.getMeetsBySwimmer(widget.swimmerId);
    });
  }

  Future<void> _confirmDelete(BuildContext context, SwimMeet meet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('DELETE MEET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('Are you sure you want to delete "${meet.title}" and all the associated results for this meet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteMeetForSwimmer(meet.id!, widget.swimmerId);
      _refreshMeets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meet deleted successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<SwimMeet>>(
      future: _meetsFuture,
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
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            
            if (isWide) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: meets.length,
                itemBuilder: (context, index) {
                  return _buildMeetCard(context, meets[index], isDark);
                },
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: meets.length,
              itemBuilder: (context, index) {
                return _buildMeetCard(context, meets[index], isDark);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMeetCard(BuildContext context, SwimMeet meet, bool isDark) {
    final color = meet.course == 'SCM' ? AppColors.primary : AppColors.accent;
    
    return Card(
      margin: EdgeInsets.zero,
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
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(
          meet.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
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
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded, 
                color: AppColors.error.withOpacity(0.7),
                size: 20,
              ),
              onPressed: () => _confirmDelete(context, meet),
              tooltip: 'Delete Meet',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        children: [
          FutureBuilder<List<SwimEvent>>(
            future: _dbHelper.getEventsByMeet(meet.id!, widget.swimmerId),
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
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.background.withOpacity(0.5) : AppColors.lightBackground.withOpacity(0.5),
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: events.map((event) => ListTile(
                    title: Text(
                      '${event.distance}m ${event.stroke}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    trailing: Text(
                      event.formattedTime,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
  }
}
