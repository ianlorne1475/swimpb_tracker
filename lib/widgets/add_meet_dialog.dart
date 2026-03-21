import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/meet.dart';
import '../models/event.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';

class AddMeetDialog extends StatefulWidget {
  final Swimmer? initialSwimmer;
  final SwimMeet? meetToEdit;

  const AddMeetDialog({super.key, this.initialSwimmer, this.meetToEdit});

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
    
    if (widget.meetToEdit != null) {
      _titleController.text = widget.meetToEdit!.title;
      _date = widget.meetToEdit!.date;
      _course = widget.meetToEdit!.course;
      
      // Load existing events
      _loadExistingEvents();
    }
  }

  Future<void> _loadExistingEvents() async {
    if (widget.meetToEdit?.id != null && _selectedSwimmer?.id != null) {
      final events = await _dbHelper.getEventsByMeet(widget.meetToEdit!.id!, _selectedSwimmer!.id!);
      if (mounted) {
        setState(() {
          _entries.clear();
          for (var e in events) {
            _entries.add(EventEntry()
              ..distance = e.distance
              ..stroke = e.stroke
              ..timeStr = e.formattedTime
            );
          }
          if (_entries.isEmpty) _entries.add(EventEntry());
        });
      }
    }
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
      title: Text(
        widget.meetToEdit != null ? 'EDIT SWIM MEET' : 'ADD SWIM MEET',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
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
                          controller: data.controller,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          decoration: fieldDecoration('M:SS.hh'),
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
              try {
                final meet = SwimMeet(
                  id: widget.meetToEdit?.id,
                  title: _titleController.text, 
                  date: _date, 
                  course: _course
                );
                
                int meetId;
                if (widget.meetToEdit != null) {
                  await _dbHelper.updateMeet(meet);
                  meetId = meet.id!;
                  await _dbHelper.deleteEventsByMeetAndSwimmer(meetId, _selectedSwimmer!.id!);
                } else {
                  meetId = await _dbHelper.insertMeet(meet);
                }
                
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
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving meet: $e')),
                  );
                }
              }
            } else {
              String error = '';
              if (_selectedSwimmer == null) error = 'No swimmer selected';
              else if (_entries.isEmpty) error = 'Add at least one event';
              else error = 'Please check for errors in the form';
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
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
          child: Text(
            widget.meetToEdit != null ? 'UPDATE MEET' : 'SAVE MEET', 
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)
          ),
        ),
      ],
    );
  }

  int _parseTimeToMs(String timeStr) {
    try {
      final clean = timeStr.trim().replaceAll(':', '.');
      final parts = clean.split('.');
      
      if (parts.length >= 3) {
        final m = int.parse(parts[parts.length - 3]);
        final s = int.parse(parts[parts.length - 2]);
        final hStr = parts[parts.length - 1];
        final h = int.parse(hStr.padRight(2, '0').substring(0, 2));
        return (m * 60000) + (s * 1000) + (h * 10);
      } else if (parts.length == 2) {
        final s = int.parse(parts[0]);
        final hStr = parts[1];
        final h = int.parse(hStr.padRight(2, '0').substring(0, 2));
        return (s * 1000) + (h * 10);
      } else if (parts.length == 1) {
        return (int.tryParse(parts[0]) ?? 0) * 1000;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var entry in _entries) {
      entry.controller.dispose();
    }
    super.dispose();
  }
}

class EventEntry {
  int distance = 50;
  String stroke = 'Freestyle';
  final TextEditingController controller = TextEditingController();
  
  String get timeStr => controller.text;
  set timeStr(String val) => controller.text = val;
}
