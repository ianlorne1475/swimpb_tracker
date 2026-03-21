import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/meet.dart';
import '../models/event.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';

class AddMeetDialog extends StatefulWidget {
  final Swimmer? initialSwimmer;
  const AddMeetDialog({super.key, this.initialSwimmer});

  @override
  State<AddMeetDialog> createState() => _AddMeetDialogState();
}

class _AddMeetDialogState extends State<AddMeetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _date = DateTime.now();
  String _course = 'SCM';
  
  final List<EventEntry> _entries = [EventEntry()];
  final _dbHelper = DatabaseHelper();
  Swimmer? _selectedSwimmer;

  @override
  void initState() {
    super.initState();
    _selectedSwimmer = widget.initialSwimmer;
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark ? const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ) : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.lightTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: const Text(
        'ADD SWIM MEET',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Meet Title',
                  prefixIcon: Icon(Icons.emoji_events_outlined, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) => v!.isEmpty ? 'Meet title is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        child: Text(
                          DateFormat('d MMM yy').format(_date),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _course,
                      decoration: const InputDecoration(
                        labelText: 'Course',
                        prefixIcon: Icon(Icons.straighten_rounded, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: ['SCM', 'LCM'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => _course = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: const [
                    SizedBox(width: 52, child: Text('DIST', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1, color: AppColors.primary))),
                    SizedBox(width: 6),
                    Expanded(child: Text('STROKE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1, color: AppColors.primary))),
                    SizedBox(width: 6),
                    SizedBox(width: 88, child: Text('TIME', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1, color: AppColors.primary))),
                    SizedBox(width: 28),
                  ],
                ),
              ),
              ..._entries.asMap().entries.map((entry) {
                int idx = entry.key;
                EventEntry data = entry.value;

                InputDecoration fieldDecoration(String hint) => InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.surface.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                  isDense: true, 
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary, width: 1)),
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.background.withOpacity(0.7) : AppColors.lightBorder.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.border : AppColors.lightBorder.withOpacity(0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<int>(
                            value: data.distance,
                            decoration: fieldDecoration(''),
                            icon: const Icon(Icons.arrow_drop_down, size: 14),
                            items: [50, 100, 200, 400, 800, 1500].map((d) => DropdownMenuItem(
                              value: d, 
                              child: Text('${d}m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                            )).toList(),
                            onChanged: (v) => setState(() => data.distance = v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String>(
                            value: data.stroke,
                            decoration: fieldDecoration(''),
                            icon: const Icon(Icons.arrow_drop_down, size: 14),
                            items: ['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'].map((s) => DropdownMenuItem(
                              value: s, 
                              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                            )).toList(),
                            onChanged: (v) => setState(() => data.stroke = v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          initialValue: data.timeStr,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          decoration: fieldDecoration('M:SS.hh'),
                          onChanged: (v) => data.timeStr = v,
                          validator: (v) => v!.isEmpty ? '' : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _entries.removeAt(idx)),
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _entries.add(EventEntry())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('ADD EVENT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate() && _selectedSwimmer != null && _entries.isNotEmpty) {
              final meet = SwimMeet(title: _titleController.text, date: _date, course: _course);
              final meetId = await _dbHelper.insertMeet(meet);
              
              for (var entry in _entries) {
                final event = SwimEvent(
                  meetId: meetId,
                  swimmerId: _selectedSwimmer!.id!,
                  distance: entry.distance,
                  stroke: entry.stroke,
                  course: _course,
                  timeMs: _parseTimeToMs(entry.timeStr),
                  date: _date.toIso8601String(),
                );
                await _dbHelper.insertEvent(event);
              }
              if (mounted) Navigator.pop(context, true);
            } else if (_entries.isEmpty) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please add at least one event')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          child: const Text('SAVE MEET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
        ),
      ],
    );
  }

  int _parseTimeToMs(String timeStr) {
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final mins = int.parse(parts[0]);
        final secsParts = parts[1].split('.');
        final secs = int.parse(secsParts[0]);
        final hundredths = int.parse(secsParts[1]);
        return (mins * 60 * 1000) + (secs * 1000) + (hundredths * 10);
      } else {
        final parts = timeStr.split('.');
        final secs = int.parse(parts[0]);
        final hundredths = int.parse(parts[1]);
        return (secs * 1000) + (hundredths * 10);
      }
    } catch (e) {
      return 0;
    }
  }
}

class EventEntry {
  int distance = 50;
  String stroke = 'Freestyle';
  String timeStr = '';
}
