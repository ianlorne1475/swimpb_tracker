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
  List<Swimmer> _swimmers = [];
  Swimmer? _selectedSwimmer;

  @override
  void initState() {
    super.initState();
    _loadSwimmers();
  }

  Future<void> _loadSwimmers() async {
    final swimmers = await _dbHelper.getSwimmers();
    setState(() {
      _swimmers = swimmers;
      if (widget.initialSwimmer != null) {
        _selectedSwimmer = _swimmers.cast<Swimmer?>().firstWhere((s) => s?.id == widget.initialSwimmer!.id, orElse: () => _swimmers.isNotEmpty ? _swimmers.first : null);
      } else if (_swimmers.isNotEmpty) {
        _selectedSwimmer = _swimmers.first;
      }
    });
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
      title: const Text(
        'ADD SWIM MEET',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_swimmers.isNotEmpty) ...[
                DropdownButtonFormField<Swimmer>(
                  value: _selectedSwimmer,
                  decoration: const InputDecoration(
                    labelText: 'Swimmer',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  items: _swimmers.map((s) => DropdownMenuItem(value: s, child: Text(s.fullName))).toList(),
                  onChanged: (s) => setState(() => _selectedSwimmer = s),
                  validator: (v) => v == null ? 'Swimmer is required' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Meet Title',
                  prefixIcon: Icon(Icons.emoji_events_outlined, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'Meet title is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                        ),
                        child: Text(
                          DateFormat('d MMM yyyy').format(_date),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _course,
                      decoration: const InputDecoration(
                        labelText: 'Course',
                        prefixIcon: Icon(Icons.straighten_rounded, size: 20),
                      ),
                      items: ['SCM', 'LCM'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _course = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'EVENTS',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              ..._entries.asMap().entries.map((entry) {
                int idx = entry.key;
                EventEntry data = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.background : AppColors.lightBorder.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.border : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<int>(
                                value: data.distance,
                                decoration: const InputDecoration(
                                  labelText: 'Dist', 
                                  isDense: true, 
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  labelStyle: TextStyle(fontSize: 10),
                                ),
                                items: [50, 100, 200, 400, 800, 1500].map((d) => DropdownMenuItem(
                                  value: d, 
                                  child: Text('${d}m', style: const TextStyle(fontSize: 12))
                                )).toList(),
                                onChanged: (v) => setState(() => data.distance = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 5,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: data.stroke,
                                decoration: const InputDecoration(
                                  labelText: 'Stroke', 
                                  isDense: true, 
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  labelStyle: TextStyle(fontSize: 10),
                                ),
                                items: ['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'].map((s) => DropdownMenuItem(
                                  value: s, 
                                  child: Text(s, style: const TextStyle(fontSize: 12))
                                )).toList(),
                                onChanged: (v) => setState(() => data.stroke = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              initialValue: data.timeStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                hintText: 'SS.hh',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                labelStyle: TextStyle(fontSize: 10),
                              ),
                              onChanged: (v) => data.timeStr = v,
                              validator: (v) => v!.isEmpty ? 'Req' : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 20),
                            onPressed: () => setState(() => _entries.removeAt(idx)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _entries.add(EventEntry())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('ADD ANOTHER EVENT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                ),
              ),
            ],
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
              fontSize: 12,
              letterSpacing: 1,
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('SAVE MEET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
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
