import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

class OcrReviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> extractedEvents;
  final String course;
  final Swimmer? selectedSwimmer;

  const OcrReviewDialog({
    super.key,
    required this.extractedEvents,
    required this.course,
    this.selectedSwimmer,
  });

  @override
  State<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends State<OcrReviewDialog> {
  late List<Map<String, dynamic>> _events;
  late List<bool> _selected;
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.extractedEvents);
    _selected = List.filled(_events.length, true);
    
    final first = _events.isNotEmpty ? _events.first : null;
    _nameController = TextEditingController(text: widget.selectedSwimmer?.firstName ?? first?['firstName'] ?? '');
    _surnameController = TextEditingController(text: widget.selectedSwimmer?.surname ?? first?['surname'] ?? '');
    
    final dobStr = first?['dob']?.toString();
    _dob = widget.selectedSwimmer?.dob ?? (dobStr != null ? DateTime.tryParse(dobStr) : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Review OCR Results'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Swimmer info section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Importing Results For:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _nameController,
                      builder: (context, nameValue, _) => ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _surnameController,
                        builder: (context, surnameValue, _) {
                          if (nameValue.text.trim().isEmpty || surnameValue.text.trim().isEmpty) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                                  SizedBox(width: 4),
                                  Expanded(child: Text('Swimmer not detected. Please enter name below.', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'First Name', isDense: true),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _surnameController,
                            decoration: const InputDecoration(labelText: 'Surname', isDense: true),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_events.isEmpty)
                const Center(child: Text('No results could be identified in the image.'))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return CheckboxListTile(
                        value: _selected[index],
                        onChanged: (val) => setState(() => _selected[index] = val!),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: event['distance'].toString(),
                                    decoration: const InputDecoration(labelText: 'Dist', isDense: true),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    onChanged: (val) => _events[index]['distance'] = int.tryParse(val) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: TextFormField(
                                    initialValue: event['time'],
                                    decoration: const InputDecoration(labelText: 'Time', isDense: true),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      TimeInputFormatter(),
                                    ],
                                    onChanged: (val) => _events[index]['time'] = val,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly', 'IM'].contains(event['stroke']) 
                                  ? event['stroke'] 
                                  : 'Freestyle',
                              decoration: const InputDecoration(labelText: 'Stroke', isDense: true),
                              isExpanded: true,
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                              items: ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly', 'IM']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (val) => setState(() => _events[index]['stroke'] = val!),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.containsKey('meetTitle') && event['meetTitle'] != null
                                  ? 'Meet: ${event['meetTitle']} (${event['meetDate'] ?? ""})'
                                  : 'Detected: "${event['original']}"',
                              style: TextStyle(
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _events.isEmpty ? null : () {
            final List<Map<String, dynamic>> finalResults = [];
            for (int i = 0; i < _events.length; i++) {
              if (_selected[i]) {
                final Map<String, dynamic> e = Map.from(_events[i]);
                e['swimmerFirstName'] = _nameController.text.trim();
                e['swimmerSurname'] = _surnameController.text.trim();
                e['swimmerDob'] = _dob?.toIso8601String();
                finalResults.add(e);
              }
            }
            Navigator.pop(context, finalResults);
          },
          child: const Text('Import Selected'),
        ),
      ],
    );
  }
}
