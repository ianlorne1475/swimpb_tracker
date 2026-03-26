import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class HelpReleaseNotesTile extends StatefulWidget {
  const HelpReleaseNotesTile({super.key});

  @override
  State<HelpReleaseNotesTile> createState() => _HelpReleaseNotesTileState();
}

class _HelpReleaseNotesTileState extends State<HelpReleaseNotesTile> {
  bool _importExportExpanded = false;
  bool _techDetailsExpanded = false;
  bool _settingsMenuExpanded = false;
  bool _additionalInfoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.lightBorder,
          width: 2,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'SwimPB Tracker v1.1.4',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help and Release Notes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Overview'),
                  _buildBodyText(context, 'This README file is intended to answer some basic questions related to app content and function.\n\nThe app can track multiple swimmers personal best times. It will track Short Course and Long Course times.'),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'App Organization'),
                  _buildBodyText(context, 'The top tile displays the swimmers profile information. The app is organised in into 4 tabs that record the following:'),
                  const SizedBox(height: 12),
                  _buildBulletItem(context, '1', 'PB times arranged by course type, distance and stroke.'),
                  _buildBulletItem(context, '2', 'The swimmers 5 most recent times selected by distance, stroke and course type.'),
                  _buildBulletItem(context, '3', 'Swimmer progress graphs selected by distance, stroke, course type and time period.'),
                  _buildBulletItem(context, '4', 'A historical list of swim meets that the swimmer has participated in together with all event information and times.'),
                  
                  const SizedBox(height: 24),
                  _buildCollapsibleSection(
                    context,
                    'Settings Menu',
                    _settingsMenuExpanded,
                    () => setState(() => _settingsMenuExpanded = !_settingsMenuExpanded),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBodyText(context, 'The settings menu allows the user to manage the following:'),
                        const SizedBox(height: 12),
                        _buildBulletItem(context, '1', 'Add a new swimmer.'),
                        _buildBulletItem(
                          context, 
                          '2', 
                          'Bulk import swimmer data from .xlsx, .csv or photo files (OCR). Download sample file here.',
                          onTap: () => _shareSampleFile(context),
                        ),
                        _buildBulletItem(
                          context, 
                          '3', 
                          'Bulk export swimmer data to either a .xlsx or .csv file.',
                        ),
                        _buildBulletItem(context, '4', 'Generate various reports for personal bests, national qualification and personal goals.'),
                        _buildBulletItem(context, '5', 'View and filter qualification standards for SNAG 2026.'),
                        _buildBulletItem(context, '6', 'Toggle the app from light mode to dark mode.'),
                        _buildBulletItem(context, '7', 'Delete a swimmer profile and their swim data.'),
                        _buildBulletItem(context, '8', 'Delete swim data for a selected swimmer.'),
                        _buildBulletItem(context, '9', 'Perform a factory reset (Clear All Data).'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildCollapsibleSection(
                    context,
                    'Importing & Exporting Data',
                    _importExportExpanded,
                    () => setState(() => _importExportExpanded = !_importExportExpanded),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBodyText(context, 'Managing your data is simple, whether you\'re tracking one swimmer or a whole team:'),
                        const SizedBox(height: 12),
                        _buildBulletItem(
                          context, 
                          '•', 
                          'Bringing Data In: You can quickly add lots of records at once using an Excel or CSV file. Tap "Download sample file here" in the app menu to get a template. You can include results for just one person or a whole team in the same file! Once ready, use the "Import" option to upload your file.',
                          onTap: () => _shareSampleFile(context),
                        ),
                        _buildBulletItem(
                          context, 
                          '•', 
                          'Saving Individual Data: If you export data for a single swimmer, it will be saved as a single Excel or CSV file.',
                        ),
                        _buildBulletItem(
                          context, 
                          '•', 
                          'Saving Team Data: If you export data for multiple swimmers or a whole team, the app will create a ZIP file. This is a special "folder" that keeps everything together—including swimmer photos—so they stay linked to the right profiles when you move them to another device.',
                        ),
                        _buildBodyText(context, '• Photo Scans: You can also use your camera to scan results directly from a photo. The app will "read" the times and help you add them to your history.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildCollapsibleSection(
                    context,
                    'Technical Column Details (for CSV)',
                    _techDetailsExpanded,
                    () => setState(() => _techDetailsExpanded = !_techDetailsExpanded),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBodyText(context, 'If you are manually creating or editing a CSV file, please ensure it has these headers:'),
                        const SizedBox(height: 12),
                        _buildBulletItem(context, '•', 'FirstName, Surname: Swimmer\'s name.'),
                        _buildBulletItem(context, '•', 'Gender: \'Male\' or \'Female\'.'),
                        _buildBulletItem(context, '•', 'DOB: Date of Birth (YYYY-MM-DD).'),
                        _buildBulletItem(context, '•', 'Nationality: 2-letter country code (e.g., SG).'),
                        _buildBulletItem(context, '•', 'Club: Swimmer\'s club name (optional).'),
                        _buildBulletItem(context, '•', 'MeetTitle: Name of the swim meet.'),
                        _buildBulletItem(context, '•', 'MeetDate: Date of the meet (YYYY-MM-DD).'),
                        _buildBulletItem(context, '•', 'Course: \'SCM\' or \'LCM\'.'),
                        _buildBulletItem(context, '•', 'Distance: Numeric distance (50, 100, 200, etc.).'),
                        _buildBulletItem(context, '•', 'Stroke: \'Freestyle\', \'Backstroke\', \'Breaststroke\', \'Butterfly\', or \'IM\'.'),
                        _buildBulletItem(context, '•', 'Time: Result or goal time in format \'MM:SS.hh\' or \'SS.hh\'.'),
                        _buildBulletItem(context, '•', 'DataType: \'result\' (default) or \'goal\'.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildCollapsibleSection(
                    context,
                    'Additional Information',
                    _additionalInfoExpanded,
                    () => setState(() => _additionalInfoExpanded = !_additionalInfoExpanded),
                    _buildBodyText(context, 'The app includes the LCM qualification times as used for the SNAG 2026 meet.\n\nThe "Qualification Times" viewer in the Settings menu allows users to browse all 54 qualification standards at a glance. It features a high-density, row-based layout and a 5-way stroke selector (Butterfly, Backstroke, Breaststroke, Freestyle, IM) for fast navigation between event types.\n\nAny time in the PB tab that meets the qualification time is annotated with a gold QT badge. All LCM PB times also include the delta between the PB and QT times.\n\nAny times in the Recent tab that meet the qualification time are annotated with a gold QT badge.\n\nThe graphs displayed in the Chart tab for LCM selections include the qualification standard as a green horizontal line on the graph.\n\nAdditionally, users can set their own custom target "Goals" for any event. This is done by tapping the bulls-eye icon on the Chart tab. Custom goals are displayed as blue dashed lines on the graphs, and as a target time on the PB and Recent tabs.\n\nWhen generating reports from Settings, you will be prompted to select the specific swimmer for whom the report is intended.\n\nFor meet records on the History tab, users can now quickly toggle between All, SCM, and LCM meets using the three-way course filter at the top. SCM meets are annotated in blue, and LCM meets are annotated in green.\n\nSwimmer age is calculated as of the 31st December, this is in line with Singapore Aquatics policy.'),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Contact'),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('mailto:trisoftsg@gmail.com')),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'trisoftsg@gmail.com',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'License / Copyright'),
                  _buildBodyText(context, 'Copyright (c) 2026 trisoftsg. All Rights Reserved.'),
                  const SizedBox(height: 12),
                  _buildBodyText(context, 'This software and associated documentation files are proprietary to trisoftsg.'),
                  const SizedBox(height: 12),
                  _buildBodyText(context, 'Unauthorized copying, modification, or distribution of this software, via any medium, is strictly prohibited.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection(
    BuildContext context, 
    String title, 
    bool isExpanded, 
    VoidCallback onToggle, 
    Widget content
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildSectionTitle(context, title),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          content,
        ],
      ],
    );
  }

  void _shareSampleFile(BuildContext context) async {
    try {
      final ByteData data = await rootBundle.load('assets/samples/surname__firstname__yyyymmdd.csv');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/surname_firstname_yyyymmdd.csv');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'SwimPB Tracker Sample Import Template',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing sample file: $e')),
        );
      }
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.primary 
              : AppColors.primary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBodyText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.6,
        fontSize: 14,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textPrimary
            : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String leading, String text, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  leading,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: text.contains('Download sample file here') 
                            ? text.split('Download sample file here')[0]
                            : text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          fontSize: 14,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (text.contains('Download sample file here'))
                        TextSpan(
                          text: 'Download sample file here.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
