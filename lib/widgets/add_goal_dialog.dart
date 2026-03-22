import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  DateTime? _targetDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(
      text: widget.existingGoal?.formattedTime ?? '',
    );
    _targetDate = widget.existingGoal?.targetDate;
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
              keyboardType: TextInputType.text,
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a time';
                if (_parseTimeToMs(value) == null) return 'Invalid format (e.g. 1:05.20)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(() => _targetDate = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Target Date (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _targetDate != null 
                      ? DateFormat('d MMM yyyy').format(_targetDate!) 
                      : 'No date set',
                  style: TextStyle(
                    color: _targetDate != null 
                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                        : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
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
                  targetDate: _targetDate,
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
