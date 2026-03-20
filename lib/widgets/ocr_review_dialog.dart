import 'package:flutter/material.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';

class OcrReviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> extractedEvents;
  final String course;

  const OcrReviewDialog({
    super.key,
    required this.extractedEvents,
    required this.course,
  });

  @override
  State<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends State<OcrReviewDialog> {
  late List<Map<String, dynamic>> _events;
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.extractedEvents);
    _selected = List.filled(_events.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Review OCR Results'),
      content: SizedBox(
        width: double.maxFinite,
        child: _events.isEmpty
            ? const Center(child: Text('No results could be identified in the image.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return CheckboxListTile(
                    value: _selected[index],
                    onChanged: (val) => setState(() => _selected[index] = val!),
                    title: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: event['distance'].toString(),
                            decoration: const InputDecoration(labelText: 'Dist', isDense: true),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _events[index]['distance'] = int.tryParse(val) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: event['stroke'],
                            decoration: const InputDecoration(labelText: 'Stroke', isDense: true),
                            items: ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly', 'IM']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) => setState(() => _events[index]['stroke'] = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: event['time'],
                            decoration: const InputDecoration(labelText: 'Time', isDense: true),
                            onChanged: (val) => _events[index]['time'] = val,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.containsKey('meetTitle'))
                            Text(
                              'Meet: ${event['meetTitle']} (${event['meetDate']})',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          Text(
                            'Detected: "${event['original']}"',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                finalResults.add(_events[i]);
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
