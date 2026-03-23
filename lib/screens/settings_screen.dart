import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../widgets/help_notes_tile.dart';
import '../widgets/feedback_dialog.dart';
import '../models/swimmer.dart';

class SettingsScreen extends StatefulWidget {
  final List<Swimmer> swimmers;
  final Swimmer? selectedSwimmer;
  final VoidCallback onAddSwimmer;
  final VoidCallback onImportData;
  final VoidCallback onExportData;
  final VoidCallback onReports;
  final VoidCallback onDeleteRaceData;
  final VoidCallback onClearAllData;
  final Function(Swimmer) onDeleteSwimmer;

  const SettingsScreen({
    super.key,
    required this.swimmers,
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
            subtitle: 'Add data from an Excel/CSV file or photo scan.',
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
              // Share logic would go here
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
              if (widget.swimmers.isNotEmpty) {
                widget.onDeleteSwimmer(widget.selectedSwimmer ?? widget.swimmers.first);
              }
            },
          ),
          _buildSettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Delete Race Data',
            subtitle: 'Clear all results for a selected swimmer.',
            isDanger: true,
            onTap: widget.onDeleteRaceData,
          ),
          _buildSettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Clear All Data',
            subtitle: 'Factory reset: removes all swimmers and data.',
            isDanger: true,
            onTap: widget.onClearAllData,
          ),

          const Divider(),
          _buildSettingsTile(
            icon: Icons.power_settings_new_rounded,
            title: 'Exit App',
            subtitle: 'Close the application cleanly.',
            isDanger: true,
            onTap: () => SystemNavigator.pop(),
          ),
          const SizedBox(height: 40),
        ],
      ),
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
