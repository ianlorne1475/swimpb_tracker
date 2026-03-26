import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';
import '../../models/meet.dart';
import '../../models/event.dart';
import '../../models/swimmer.dart';
import '../../widgets/add_meet_dialog.dart';

import '../../theme/app_theme.dart';

class MeetsTab extends StatefulWidget {
  final int swimmerId;
  final VoidCallback? onDataChanged;
  const MeetsTab({super.key, required this.swimmerId, this.onDataChanged});

  @override
  State<MeetsTab> createState() => _MeetsTabState();
}

class _MeetsTabState extends State<MeetsTab> {
  final _dbHelper = DatabaseHelper();
  late Future<List<SwimMeet>> _meetsFuture;
  String _selectedCourse = 'All';
  Set<int> _pbEventIds = {};

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
      _meetsFuture = _dbHelper.getMeetsBySwimmer(widget.swimmerId, course: _selectedCourse);
    });
    _calculatePBs();
  }

  Future<void> _calculatePBs() async {
    final allEvents = await _dbHelper.getEventsBySwimmer(widget.swimmerId);
    // getEventsBySwimmer returns date DESC, reverse for chronological processing
    final sortedEvents = allEvents.reversed.toList();
    
    final Set<int> pbIds = {};
    final Map<String, int> bestTimes = {};

    for (final event in sortedEvents) {
      final key = "${event.distance}-${event.stroke}-${event.course}";
      final currentTime = event.timeMs;
      
      if (!bestTimes.containsKey(key) || currentTime < bestTimes[key]!) {
        pbIds.add(event.id!);
        bestTimes[key] = currentTime;
      }
    }

    if (mounted) {
      setState(() {
        _pbEventIds = pbIds;
      });
    }
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
      if (widget.onDataChanged != null) {
        widget.onDataChanged!();
      }
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.border : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('ALL'), icon: Icon(Icons.all_inclusive_rounded, size: 16)),
                  ButtonSegment(value: 'LCM', label: Text('LCM'), icon: Icon(Icons.pool_rounded, size: 16)),
                  ButtonSegment(value: 'SCM', label: Text('SCM'), icon: Icon(Icons.waves_rounded, size: 16)),
                ],
                selected: {_selectedCourse},
                showSelectedIcon: false,
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedCourse = newSelection.first;
                    _refreshMeets();
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surface : Colors.white,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                  side: BorderSide.none, // Hide default border to use Card's border
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<SwimMeet>>(
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
                        _selectedCourse == 'All' ? 'NO MEETS RECORDED' : 'NO $_selectedCourse MEETS',
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
          ),
        ),
      ],
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
              if (meet.club != null && meet.club!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary.withOpacity(0.5) : AppColors.lightTextSecondary.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  meet.club!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
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
                Icons.edit_rounded, 
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (context) => AddMeetDialog(
                    initialSwimmer: Swimmer(id: widget.swimmerId, firstName: '', surname: '', dob: DateTime.now(), nationality: '', gender: ''),
                    meetToEdit: meet,
                  ),
                );
                if (result == true) {
                  _refreshMeets();
                  if (widget.onDataChanged != null) {
                    widget.onDataChanged!();
                  }
                }
              },
              tooltip: 'Edit Meet',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
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
                  children: events.map((event) {
                    final isPb = _pbEventIds.contains(event.id);
                    return ListTile(
                      title: Text(
                        '${event.distance}m ${event.stroke}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      trailing: SizedBox(
                        width: 110, // Sufficient width for both badge and time
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isPb)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                ),
                                child: const Text(
                                  'PB',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              event.formattedTime,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      dense: false,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
