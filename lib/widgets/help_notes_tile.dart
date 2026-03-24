import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class HelpReleaseNotesTile extends StatelessWidget {
  const HelpReleaseNotesTile({super.key});

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
                          'SwimPB Tracker v1.0.1',
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
                  _buildBodyText(context, 'The top tile displays the swimmers profile information. The app is organised in to 4 tabs that record the following:'),
                  const SizedBox(height: 12),
                  _buildBulletItem(context, '1', 'PB times arranged by course type, distance and stroke.'),
                  _buildBulletItem(context, '2', 'The swimmers 5 most recent times selected by distance, stroke and course type.'),
                  _buildBulletItem(context, '3', 'Swimmer progress graphs selected by distance, stroke, course type and time period on the Chart tab.'),
                  _buildBulletItem(context, '4', 'A historical list of swim meets that the swimmer has participated in together with all event information and times.'),
                  
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Settings Menu'),
                    _buildBodyText(context, 'The settings menu allows the user to manage the following:'),
                    const SizedBox(height: 12),
                    _buildBulletItem(context, '1', 'Add a new swimmer.'),
                    _buildBulletItem(
                      context, 
                      '2', 
                      'Add data from an Excel/CSV file. See the "Importing & Exporting" section below.',
                    ),
                    _buildBulletItem(
                      context, 
                      '3', 
                      'Bulk Export: Save your data to keep it safe or move it to another device.',
                    ),
                    _buildBulletItem(context, '4', 'Generate various reports for personal bests, national qualification and personal goals.'),
                    _buildBulletItem(context, '5', 'Toggle the app from light mode to dark mode.'),
                    _buildBulletItem(context, '6', 'Delete a swimmer profile and their swim data.'),
                    _buildBulletItem(context, '7', 'Delete swim data for a selected swimmer.'),

                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Importing & Exporting Data'),
                    _buildBodyText(context, 'Managing your data is simple, whether you\'re tracking one swimmer or a whole team:'),
                    const SizedBox(height: 12),
                    _buildBulletItem(
                      context, 
                      '1', 
                      'Bringing Data In: You can quickly add lots of records at once using an Excel or CSV file. Tap "Download sample file here" to get a template. You can include results for just one person or a whole team in the same file!',
                      onTap: () => _shareSampleFile(context),
                    ),
                    _buildBulletItem(
                      context, 
                      '2', 
                      'Saving Individual Data: If you export data for a single swimmer, it will be saved as a single Excel or CSV file.',
                    ),
                    _buildBulletItem(
                      context, 
                      '3', 
                      'Saving Team Data: If you export data for multiple swimmers or a whole team, the app will create a ZIP file. This is a special folder that keeps everything together—including swimmer photos—so they stay linked to the right profiles.',
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Release Notes (v1.1.0)'),
                    _buildBodyText(context, '• Enhanced multi-swimmer export logic.\n• Improved PDF report layouts.\n• Added support for team-wide ZIP exports with photos.'),

                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Additional Information'),
                    _buildBodyText(context, 'The app includes the LCM qualification times as used for the SNAG 2026 meet.\n\nAny time in the PB tab that meets the qualification time is annotated with a gold QT badge. All LCM PB times also include the delta between the PB and QT times.\n\nAny times in the Recent tab that meet the qualification time are annotated with a gold QT badge.\n\nThe graphs displayed in the Chart tab for LCM selections include the qualification standard as a green horizontal line on the graph.\n\nAdditionally, users can set their own custom target "Goals" for any event by tapping the bulls-eye icon on the Chart tab. Custom goals are displayed as blue dashed lines on the graphs, and as a target time on the PB and Recent tabs.\n\nFor meet records on the History tab SCM meets are annotated in blue, LCM meets are annotated in green.\n\nSwimmer age is calculated as of the 31st December, this is in line with Singapore Aquatics policy.'),
                    

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
