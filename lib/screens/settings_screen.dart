import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../widgets/help_notes_tile.dart';
import '../widgets/feedback_dialog.dart';
import '../models/swimmer.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<List<Swimmer>> swimmersNotifier;
  final ValueNotifier<Set<int>> swimmerIdsWithResultsNotifier;
  final Swimmer? selectedSwimmer;
  final VoidCallback onAddSwimmer;
  final VoidCallback onImportData;
  final VoidCallback onExportData;
  final VoidCallback onReports;
  final Function(Swimmer?) onDeleteRaceData;
  final VoidCallback onClearAllData;
  final Function(Swimmer) onDeleteSwimmer;

  const SettingsScreen({
    super.key,
    required this.swimmersNotifier,
    required this.swimmerIdsWithResultsNotifier,
    this.selectedSwimmer,
    required this.onAddSwimmer,
    required this.onImportData,
    required this.onExportData,
    required this.onReports,
    required this.onDeleteRaceData,
    required this.onClearAllData,
    required this.onDeleteSwimmer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Swimmer>>(
      valueListenable: widget.swimmersNotifier,
      builder: (context, currentSwimmers, _) {
        return ValueListenableBuilder<Set<int>>(
          valueListenable: widget.swimmerIdsWithResultsNotifier,
          builder: (context, idsWithResults, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Settings'),
                centerTitle: true,
              ),
              body: ListView(
                children: [
                  _buildCategoryHeader('Profiles & Data Management'),
                  _buildSettingsTile(
                    icon: Icons.person_add_outlined,
                    title: 'Add New Swimmer',
                    subtitle: 'Create a new profile to track personal bests.',
                    onTap: widget.onAddSwimmer,
                  ),
                  _buildSettingsTile(
                    icon: Icons.file_upload_outlined,
                    title: 'Import Data',
                    subtitle: 'Add data from an Excel/CSV file.',
                    onTap: widget.onImportData,
                  ),
                  _buildSettingsTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export Data',
                    subtitle: 'Save your team or individual history to a file.',
                    onTap: widget.onExportData,
                  ),

                  const Divider(),
                  _buildCategoryHeader('Tools & Reports'),
                  _buildSettingsTile(
                    icon: Icons.assessment_outlined,
                    title: 'Generate Reports',
                    subtitle: 'Create PDF reports for results and goals.',
                    onTap: widget.onReports,
                  ),
                  _buildSettingsTile(
                    icon: Icons.feedback_outlined,
                    title: 'App Feedback',
                    subtitle: 'Help us improve with your suggestions.',
                    onTap: () => _showFeedbackDialog(),
                  ),

                  const Divider(),
                  _buildCategoryHeader('App Preferences'),
                  SwitchListTile(
                    secondary: Icon(
                      ThemeService().isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Appearance'),
                    subtitle: Text(ThemeService().isDarkMode ? 'Currently in Dark Mode' : 'Currently in Light Mode'),
                    value: ThemeService().isDarkMode,
                    activeColor: AppColors.primary,
                    onChanged: (bool value) {
                      ThemeService().toggleTheme();
                      setState(() {});
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'App Help',
                    subtitle: 'View detailed guides and release notes.',
                    onTap: () => _showAppHelp(),
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About SwimPB Tracker',
                    subtitle: 'Version information and developer details.',
                    onTap: () => _showAboutDialog(),
                  ),
                  _buildSettingsTile(
                    icon: Icons.share_outlined,
                    title: 'Share with a Friend',
                    subtitle: 'Tell other swimmers about the app.',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing feature coming soon!')),
                      );
                    },
                  ),

                  const Divider(),
                  _buildCategoryHeader('Danger Zone', isDanger: true),
                  _buildSettingsTile(
                    icon: Icons.person_remove_outlined,
                    title: 'Delete Swimmer',
                    subtitle: 'Permanently remove a swimmer profile.',
                    isDanger: true,
                    onTap: () {
                      if (currentSwimmers.isNotEmpty) {
                        _showDangerDialog(
                          title: 'Delete Swimmer Profile',
                          description: 'Choose the profile you wish to permanently remove:',
                          confirmText: 'Delete Permanently',
                          showSwimmerSelector: true,
                          swimmersSource: currentSwimmers,
                          onConfirm: (swimmer) {
                            if (swimmer != null) {
                              widget.onDeleteSwimmer(swimmer);
                            }
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No swimmers available to delete.')),
                        );
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Delete Race Data',
                    subtitle: 'Clear all results for a selected swimmer.',
                    isDanger: true,
                    onTap: () {
                      final candidates = currentSwimmers.where((s) => idsWithResults.contains(s.id)).toList();
                      if (candidates.isNotEmpty) {
                        _showDangerDialog(
                          title: 'Delete Race Data',
                          description: 'Select a swimmer to clear their entire race history:',
                          confirmText: 'Clear All Results',
                          showSwimmerSelector: true,
                          swimmersSource: candidates,
                          onConfirm: (swimmer) {
                            if (swimmer != null) {
                              widget.onDeleteRaceData(swimmer);
                            }
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No swimmers with race data available.')),
                        );
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Clear All Data',
                    subtitle: 'Factory reset: removes all swimmers and data.',
                    isDanger: true,
                    onTap: () {
                      _showDangerDialog(
                        title: 'Clear All Data',
                        description: 'Are you absolutely sure you want to perform a factory reset?',
                        warningText: 'Warning: This will PERMANENTLY delete ALL swimmers and ALL race results for everyone.',
                        confirmText: 'Clear Everything',
                        showSwimmerSelector: false,
                        onConfirm: (_) {
                          widget.onClearAllData();
                        },
                      );
                    },
                  ),
                  const Divider(),
                  _buildSettingsTile(
                    icon: Icons.power_settings_new_rounded,
                    title: 'Exit App',
                    subtitle: 'Close the application cleanly.',
                    isDanger: true,
                    onTap: () {
                      _showDangerDialog(
                        title: 'Exit Application',
                        description: 'Are you sure you want to close SwimPB Tracker?',
                        confirmText: 'Exit Now',
                        showSwimmerSelector: false,
                        onConfirm: (_) => exit(0),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryHeader(String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: isDanger ? Colors.red : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDanger ? Colors.red : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: isDanger ? Colors.red.withOpacity(0.7) : null),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showDangerDialog({
    required String title,
    required String description,
    required String confirmText,
    String? warningText,
    bool showSwimmerSelector = false,
    List<Swimmer>? swimmersSource,
    required Function(Swimmer?) onConfirm,
  }) {
    Swimmer? selectedSwimmer;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showWarning = (showSwimmerSelector && selectedSwimmer != null) || !showSwimmerSelector;
          final currentWarning = showSwimmerSelector && selectedSwimmer != null
              ? 'Warning: All records for ${selectedSwimmer!.firstName} will be lost.'
              : warningText;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontSize: 14)),
                if (showSwimmerSelector) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Swimmer>(
                    decoration: InputDecoration(
                      labelText: 'Select Profile',
                      prefixIcon: const Icon(Icons.person_pin_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.primary.withOpacity(0.05),
                    ),
                    hint: const Text('Choose a swimmer'),
                    value: selectedSwimmer,
                    isExpanded: true,
                    items: swimmersSource?.map((swimmer) {
                      return DropdownMenuItem<Swimmer>(
                        value: swimmer,
                        child: Text(swimmer.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedSwimmer = value);
                    },
                  ),
                ],
                if (showWarning && currentWarning != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentWarning,
                            style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (showSwimmerSelector && selectedSwimmer == null) ? null : () {
                  Navigator.pop(context);
                  onConfirm(selectedSwimmer);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(confirmText),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAppHelp() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 500,
          ),
          child: const SingleChildScrollView(
            child: HelpReleaseNotesTile(),
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pool_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('SwimPB Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('v1.0.1', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A professional swimming personal best tracker for individuals and teams.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text('Developed by', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Text('trisoftsg', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('mailto:trisoftsg@gmail.com')),
              child: const Text('Contact Support'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
