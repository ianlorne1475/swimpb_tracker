import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';

class DailyGoalWidget extends StatefulWidget {
  const DailyGoalWidget({super.key});

  @override
  State<DailyGoalWidget> createState() => _DailyGoalWidgetState();
}

class _DailyGoalWidgetState extends State<DailyGoalWidget> {
  final PreferenceService _prefs = PreferenceService();
  int _distance = 0;
  final int _target = 2500; // Hardcoded target for now

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _distance = _prefs.getDailyDistance();
    });
  }

  void _addDistance(int amount) async {
    final newDistance = _distance + amount;
    await _prefs.setDailyDistance(newDistance);
    setState(() {
      _distance = newDistance;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_distance / _target).clamp(0.0, 1.0);
    final isDone = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.surface 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY TARGET',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_distance / ${_target}m',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isDone)
                const Icon(Icons.check_circle, color: Colors.green, size: 32)
              else
                IconButton.filledTonal(
                  onPressed: () => _addDistance(500),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add 500m',
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.green : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDone ? 'Goal reached! Great job!' : '${(_target - _distance).clamp(0, _target)}m remaining for today',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
