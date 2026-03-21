import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';

class AddGoalDialog extends StatefulWidget {
  final int swimmerId;
  final int distance;
  final String stroke;
  final String course;
  final SwimmerGoal? existingGoal;

  const AddGoalDialog({
    super.key,
    required this.swimmerId,
    required this.distance,
    required this.stroke,
    required this.course,
    this.existingGoal,
  });

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  late TextEditingController _timeController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(
      text: widget.existingGoal?.formattedTime ?? '',
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  int? _parseTimeToMs(String value) {
    if (value.isEmpty) return null;
    
    // Support formats:
    // ss.hh
    // m:ss.hh
    // mm:ss.hh
    
    try {
      if (value.contains(':')) {
        final parts = value.split(':');
        final minutes = int.parse(parts[0]);
        final secondParts = parts[1].split('.');
        final seconds = int.parse(secondParts[0]);
        final hundredths = secondParts.length > 1 ? int.parse(secondParts[1].padRight(2, '0').substring(0, 2)) : 0;
        
        return (minutes * 60 * 1000) + (seconds * 1000) + (hundredths * 10);
      } else {
        final parts = value.split('.');
        final seconds = int.parse(parts[0]);
        final hundredths = parts.length > 1 ? int.parse(parts[1].padRight(2, '0').substring(0, 2)) : 0;
        
        return (seconds * 1000) + (hundredths * 10);
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existingGoal == null ? 'Set Custom Goal' : 'Edit Custom Goal',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.distance}m ${widget.stroke} (${widget.course})',
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _timeController,
              decoration: InputDecoration(
                labelText: 'Target Time (e.g. 1:05.20)',
                hintText: 'mm:ss.hh',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a time';
                if (_parseTimeToMs(value) == null) return 'Invalid format (e.g. 1:05.20)';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        if (widget.existingGoal != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final timeMs = _parseTimeToMs(_timeController.text);
              if (timeMs != null) {
                final goal = SwimmerGoal(
                  id: widget.existingGoal?.id,
                  swimmerId: widget.swimmerId,
                  distance: widget.distance,
                  stroke: widget.stroke,
                  course: widget.course,
                  timeMs: timeMs,
                );
                Navigator.of(context).pop(goal);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('SAVE GOAL'),
        ),
      ],
    );
  }
}
