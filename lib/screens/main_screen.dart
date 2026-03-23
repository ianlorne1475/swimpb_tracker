import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import '../models/event.dart';
import '../services/report_service.dart';
import '../widgets/pb_certificate.dart';
import '../widgets/add_goal_dialog.dart';
import '../widgets/feedback_dialog.dart';
import 'dart:async';
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import '../database_helper.dart';
import '../widgets/ocr_review_dialog.dart';
import '../models/swimmer.dart';
import 'tabs/pb_tab.dart';
import 'tabs/recent_bests_tab.dart';
import 'tabs/progression_tab.dart';
import 'tabs/meets_tab.dart';
import '../widgets/help_notes_tile.dart';
import '../widgets/swimmer_dialog.dart';
import '../widgets/add_meet_dialog.dart';
import '../widgets/swimmer_header.dart';
import '../theme/app_theme.dart';
import '../services/bulk_import_service.dart';
import '../services/bulk_export_service.dart';
import '../services/qualifying_times_service.dart';
import '../services/theme_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BulkImportService _importService = BulkImportService();
  
  List<Swimmer> _swimmers = [];
  Swimmer? _selectedSwimmer;
  int _meetCount = 0;
  int _scmMeetCount = 0;
  int _lcmMeetCount = 0;
  int _resultCount = 0;
  int _refreshCounter = 0;
  
  bool _showTooltip = false;
  bool _isTooltipInTree = false;
  String _tooltipText = '';
  Timer? _tooltipTimer;

  int _selectedDistance = 50;
  String _selectedStroke = 'Butterfly';
  String _selectedCourse = 'LCM';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _showTabTooltip(_tabController.index);
      }
    });

    // Show tooltip on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTabTooltip(_tabController.index);
    });

    _loadSwimmers();
    QualifyingTimesService().seedSnag2026Female();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tooltipTimer?.cancel();
    super.dispose();
  }

  String _getTooltipText(int index) {
    switch (index) {
      case 0:
        return 'Personal Best times for all distances and strokes in short course and long course events';
      case 1:
        return 'Five most recent times for selected distance, stroke and SCM/LCM';
      case 2:
        return 'Graphical representation of improvements for selected distance, stroke and SCM/LCM';
      case 3:
        return 'Comprehensive list of historical swim meet results';
      default:
        return '';
    }
  }

  void _showTabTooltip(int index) {
    _tooltipTimer?.cancel();
    setState(() {
      _tooltipText = _getTooltipText(index);
      _isTooltipInTree = true;
      _showTooltip = true;
    });
    _tooltipTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showTooltip = false);
      }
    });
  }


  Future<void> _loadSwimmers({int? targetId}) async {
    final swimmers = await _dbHelper.getSwimmers();
    setState(() {
      _swimmers = swimmers;
      
      if (targetId != null) {
        // Explicitly select the requested swimmer (e.g. after adding/editing)
        try {
          _selectedSwimmer = _swimmers.firstWhere((s) => s.id == targetId);
        } catch (e) {
          _selectedSwimmer = _swimmers.isNotEmpty ? _swimmers.first : null;
        }
      } else if (_selectedSwimmer != null) {
        // Refresh the current selection's data
        try {
          _selectedSwimmer = _swimmers.firstWhere((s) => s.id == _selectedSwimmer!.id);
        } catch (e) {
          _selectedSwimmer = _swimmers.isNotEmpty ? _swimmers.first : null;
        }
      } else if (_swimmers.isNotEmpty) {
        _selectedSwimmer = _swimmers.first;
      }
      
      if (_selectedSwimmer != null) {
        _loadSwimmerData();
        _tabController.index = 0;
      }
    });
  }

  Future<void> _loadSwimmerData() async {
    if (_selectedSwimmer?.id != null) {
      final id = _selectedSwimmer!.id!;
      final count = await _dbHelper.getMeetCountBySwimmer(id);
      final scmCount = await _dbHelper.getScmMeetCountBySwimmer(id);
      final lcmCount = await _dbHelper.getLcmMeetCountBySwimmer(id);
      final eventCount = await _dbHelper.getEventCountBySwimmer(id);
      
      setState(() {
        _meetCount = count;
        _scmMeetCount = scmCount;
        _lcmMeetCount = lcmCount;
        _resultCount = eventCount;
        _refreshCounter++;
      });
    }
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


  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleImportData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        _showLoadingDialog();
        
        final count = await _importService.importFromFile(file);
        
        _hideLoadingDialog();

        if (mounted) {
          await _loadSwimmers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import complete. $count results imported.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _hideLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during import: $e')),
        );
      }
    }
  }


  Future<void> _handleDeleteRaceData() async {
    Swimmer? targetSwimmer = _selectedSwimmer;
    String targetCourse = 'All';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Race Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will delete ALL race results (SCM & LCM) for the selected swimmer. This cannot be undone.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<Swimmer>(
                value: targetSwimmer,
                decoration: const InputDecoration(labelText: 'Select Swimmer'),
                items: _swimmers.map((s) => DropdownMenuItem(value: s, child: Text(s.fullName))).toList(),
                onChanged: (s) => setDialogState(() => targetSwimmer = s),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Data'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && targetSwimmer != null) {
      await _dbHelper.deleteEventsBySwimmerAndCourse(targetSwimmer!.id!, targetCourse);
      _loadSwimmerData();
      setState(() {});
      if (mounted) {
        final message = targetCourse == 'All' 
            ? 'Deleted all results for ${targetSwimmer!.fullName}.'
            : 'Deleted $targetCourse results for ${targetSwimmer!.fullName}.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _handleClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all swimmers, meets, and events? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.clearAllData();
      setState(() {
        _selectedSwimmer = null;
        _meetCount = 0;
      });
      _loadSwimmers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared successfully.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
        title: const Text('SwimPB Tracker'),
        centerTitle: true,
        actions: [
          if (_swimmers.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.menu, 
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.textSecondary 
                    : AppColors.lightTextSecondary,
              ),
            onSelected: (value) async {
              if (value == 'add_swimmer') {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const SwimmerDialog(),
                );
                if (result is int) {
                  _loadSwimmers(targetId: result);
                }
              } else if (value == 'delete_swimmer') {
                if (_swimmers.isEmpty) return;
                
                Swimmer? swimmerToDelete = _selectedSwimmer ?? _swimmers.first;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) {
                      return AlertDialog(
                        title: const Text('Delete Swimmer'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select a swimmer to permanently delete:'),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.lightBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Swimmer>(
                                  value: swimmerToDelete,
                                  isExpanded: true,
                                  items: _swimmers.map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.fullName),
                                  )).toList(),
                                  onChanged: (v) => setDialogState(() => swimmerToDelete = v),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (swimmerToDelete != null)
                              Text(
                                'Warning: All race data and meets for ${swimmerToDelete!.fullName} will be lost forever.',
                                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: swimmerToDelete == null ? null : () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    }
                  ),
                );
                
                if (confirmed == true && swimmerToDelete != null) {
                  await _dbHelper.deleteSwimmer(swimmerToDelete!.id!);
                  if (_selectedSwimmer?.id == swimmerToDelete!.id) {
                    setState(() {
                      _selectedSwimmer = null;
                      _meetCount = 0;
                    });
                  }
                  _loadSwimmers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Swimmer ${swimmerToDelete!.fullName} deleted.')),
                    );
                  }
                }
              } else if (value == 'import_data') {
                _handleImportData();
              } else if (value == 'clear_all') {
                _handleClearAllData();
              } else if (value == 'delete_race_data') {
                _handleDeleteRaceData();
              } else if (value == 'toggle_theme') {
                ThemeService().toggleTheme();
              } else if (value == 'app_help') {
                _showAppHelp();
              } else if (value == 'reports') {
                _showReportsDialog();
              } else if (value == 'export_data') {
                _handleExportData();
              } else if (value == 'feedback') {
                showDialog(
                  context: context,
                  builder: (context) => const FeedbackDialog(),
                );
              } else if (value == 'exit') {
                SystemNavigator.pop();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_swimmer',
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Add Swimmer'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_data',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Import Individual or Team Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_data',
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline, size: 20),
                    SizedBox(width: 8),
                    Text('Export Individual or Team Data'),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(
                      ThemeService().isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(ThemeService().isDarkMode ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Reports'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'app_help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text('App Help'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'feedback',
                child: Row(
                  children: [
                    Icon(Icons.feedback_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Feedback'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (_swimmers.isNotEmpty)
                const PopupMenuItem(
                  value: 'delete_swimmer',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Swimmer'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete_race_data',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Race Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Data', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'exit',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Exit App', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedSwimmer != null)
              SwimmerHeader(
                swimmer: _selectedSwimmer!,
                swimmers: _swimmers,
                meetCount: _meetCount,
                scmCount: _scmMeetCount,
                lcmCount: _lcmMeetCount,
                resultCount: _resultCount,
                onSwimmerSelected: (swimmer) {
                  setState(() {
                    _selectedSwimmer = swimmer;
                    _loadSwimmerData();
                    _tabController.index = 0;
                  });
                },
                onEdit: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) => SwimmerDialog(swimmer: _selectedSwimmer),
                  );
                  if (result is int) {
                    _loadSwimmers(targetId: result);
                    _loadSwimmerData();
                  }
                },
                onAddMeet: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) => AddMeetDialog(initialSwimmer: _selectedSwimmer),
                  );
                  if (result == true) {
                    _loadSwimmerData();
                  }
                },
              ),
            
            if (_selectedSwimmer == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HelpReleaseNotesTile(),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppColors.surface : AppColors.lightBorder.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.pool_rounded,
                              size: 48,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'READY TO DIVE IN?',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Add a swimmer to start tracking their personal bests and meet results.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Start here if you are not importing data',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, 
                              fontStyle: FontStyle.italic, 
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (context) => const SwimmerDialog(),
                              );
                              if (result is int) {
                                _loadSwimmers(targetId: result);
                              }
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('ADD FIRST SWIMMER'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                              minimumSize: const Size(220, 48),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'If you have a formatted .xlsx file containing either a single swimmer\'s data or team data, start here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, 
                              fontStyle: FontStyle.italic, 
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _handleImportData,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('IMPORT INDIVIDUAL OR TEAM DATA'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                              minimumSize: const Size(220, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            if (_selectedSwimmer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.surface 
                        : AppColors.lightBorder.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        if (Theme.of(context).brightness == Brightness.light)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.lightTextPrimary,
                    unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.emoji_events_outlined, size: 14), SizedBox(width: 4), Text('PBs')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.access_time, size: 14), SizedBox(width: 4), Text('RECENT')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.show_chart, size: 14), SizedBox(width: 4), Text('CHART')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.description_outlined, size: 14), SizedBox(width: 4), Text('HISTORY')])),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            if (_selectedSwimmer != null)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    PersonalBestsTab(
                      key: ValueKey('pb_${_selectedSwimmer!.id}_$_refreshCounter'),
                      swimmerId: _selectedSwimmer!.id!,
                    ),
                    RecentBestsTab(
                      key: ValueKey('recent_${_selectedSwimmer!.id}_$_refreshCounter'),
                      swimmerId: _selectedSwimmer!.id!,
                      initialDistance: _selectedDistance,
                      initialStroke: _selectedStroke,
                      initialCourse: _selectedCourse,
                      onSelectionChanged: (d, s, c) {
                        setState(() {
                          _selectedDistance = d;
                          _selectedStroke = s;
                          _selectedCourse = c;
                        });
                      },
                    ),
                    ProgressionTab(
                      key: ValueKey('prog_${_selectedSwimmer!.id}_$_refreshCounter'),
                      swimmerId: _selectedSwimmer!.id!,
                      initialDistance: _selectedDistance,
                      initialStroke: _selectedStroke,
                      initialCourse: _selectedCourse,
                      onSelectionChanged: (d, s, c) {
                        setState(() {
                          _selectedDistance = d;
                          _selectedStroke = s;
                          _selectedCourse = c;
                        });
                      },
                    ),
                    MeetsTab(
                      key: ValueKey('meets_${_selectedSwimmer!.id}_$_refreshCounter'),
                      swimmerId: _selectedSwimmer!.id!,
                      onDataChanged: _loadSwimmerData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (_isTooltipInTree)
        Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: AnimatedOpacity(
                opacity: _showTooltip ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                onEnd: () {
                  if (!_showTooltip && mounted) {
                    setState(() => _isTooltipInTree = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.border 
                        : AppColors.lightBorder).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _tooltipText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

  void _handleExportData() async {
    if (_swimmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No swimmers found to export.')),
      );
      return;
    }

    // Check if only one swimmer in database
    if (_swimmers.length == 1) {
      _executeIndividualExport(_swimmers.first);
      return;
    }

    // Check if all swimmers have the same team name set
    final clubs = _swimmers
        .map((s) => s.club?.trim())
        .where((c) => c != null && c.isNotEmpty)
        .toSet();
    
    final bool allSameTeam = clubs.length == 1 && _swimmers.every((s) => s.club?.trim() == clubs.first);
    
    String exportType = allSameTeam ? 'Team' : 'Individual'; 
    Swimmer? exportSwimmer = _selectedSwimmer;
    String teamName = allSameTeam ? clubs.first! : 'Multiple Swimmers';

    final String ddmmyyyy = DateFormat('ddMMyyyy').format(DateTime.now());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(allSameTeam ? 'Team Export' : 'Multi-Swimmer Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(allSameTeam 
                ? 'All swimmers belong to "${clubs.first}".'
                : 'Multiple swimmers with different teams detected.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: exportType,
                decoration: const InputDecoration(labelText: 'Export Type'),
                items: [
                  const DropdownMenuItem(value: 'Individual', child: Text('Individual Swimmer')),
                  DropdownMenuItem(
                    value: 'Team', 
                    child: Text(allSameTeam ? 'Complete Team' : 'Multiple Swimmers'),
                  ),
                ],
                onChanged: (val) => setDialogState(() => exportType = val!),
              ),
              const SizedBox(height: 16),
              if (exportType == 'Individual')
                DropdownButtonFormField<Swimmer>(
                  value: exportSwimmer,
                  decoration: const InputDecoration(labelText: 'Select Swimmer'),
                  items: _swimmers.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.fullName),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => exportSwimmer = val),
                )
              else
                TextFormField(
                  initialValue: teamName,
                  decoration: InputDecoration(
                    labelText: allSameTeam ? 'Team Name' : 'File Identifier',
                    helperText: 'Filename will be based on "${teamName.toLowerCase().replaceAll(' ', '_')}"',
                  ),
                  onChanged: (val) => setDialogState(() => teamName = val),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (exportType == 'Individual') {
        if (exportSwimmer != null) {
          _executeIndividualExport(exportSwimmer!);
        }
      } else {
        _executeTeamExport(teamName);
      }
    }
  }

  Future<void> _executeIndividualExport(Swimmer swimmer) async {
    try {
      final exportService = BulkExportService();
      final files = await exportService.getSwimmerFullExport(swimmer.id!);
      
      if (files.isEmpty) return;

      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
      String fileName;
      Uint8List exportBytes;

      if (files.length == 1) {
        fileName = files.keys.first;
        exportBytes = files.values.first;
      } else {
        // Create ZIP
        fileName = '${swimmer.firstName}_${swimmer.surname}_$dateStr.zip';
        final encoder = ZipEncoder();
        final archive = Archive();
        files.forEach((name, bytes) {
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        });
        exportBytes = Uint8List.fromList(encoder.encode(archive)!);
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select export location',
        fileName: fileName,
        bytes: exportBytes,
      );

      if (outputFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data exported to $outputFile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeTeamExport(String teamName) async {
    try {
      final exportService = BulkExportService();
      final files = await exportService.getTeamFullExport();
      
      if (files.isEmpty) return;

      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
      String fileName;
      Uint8List exportBytes;

      // For teams, always zip if there's any file besides the XLSX (like photos)
      // Actually, if there's only one file it's the XLSX.
      if (files.length == 1) {
        fileName = files.keys.first;
        exportBytes = files.values.first;
      } else {
        fileName = '${teamName.replaceAll(" ", "_")}_$dateStr.zip';
        final encoder = ZipEncoder();
        final archive = Archive();
        files.forEach((name, bytes) {
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        });
        exportBytes = Uint8List.fromList(encoder.encode(archive)!);
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select export location',
        fileName: fileName,
        bytes: exportBytes,
      );

      if (outputFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data exported to $outputFile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReportsDialog() async {
    if (_selectedSwimmer == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Swimmer Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.stars, color: Colors.orange),
              title: const Text('National QT Report'),
              subtitle: const Text('National standards met (SNAG 2026)'),
              onTap: () async {
                Navigator.pop(context);
                final events = await _dbHelper.getEventsBySwimmer(_selectedSwimmer!.id!);
                final age = _selectedSwimmer!.calculateAge();
                final standards = await _dbHelper.getStandardsForSwimmer(age, _selectedSwimmer!.gender ?? 'Male');
                
                final pdfBytes = await ReportService.generateNationalQTReport(_selectedSwimmer!, events, standards);
                final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
                await Printing.layoutPdf(
                  onLayout: (format) async => pdfBytes,
                  name: '${_selectedSwimmer!.firstName}_${_selectedSwimmer!.surname}_${dateStr}_national_qt_report',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.track_changes, color: Colors.blue),
              title: const Text('Personal Goals Report'),
              subtitle: const Text('Route to your personal targets'),
              onTap: () async {
                Navigator.pop(context);
                final goals = await _dbHelper.getGoalsBySwimmer(_selectedSwimmer!.id!);
                final allEvents = await _dbHelper.getEventsBySwimmer(_selectedSwimmer!.id!);
                
                final pdfBytes = await ReportService.generatePersonalGoalsReport(_selectedSwimmer!, goals, allEvents);
                final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
                await Printing.layoutPdf(
                  onLayout: (format) async => pdfBytes,
                  name: '${_selectedSwimmer!.firstName}_${_selectedSwimmer!.surname}_${dateStr}_personal_goals_report',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_edu_outlined, color: Colors.orange),
              title: const Text('Personal Bests Report'),
              subtitle: const Text('Full history of swimmer PBs.'),
              onTap: () async {
                Navigator.pop(context);
                final events = await _dbHelper.getEventsBySwimmer(_selectedSwimmer!.id!);
                final pdfBytes = await ReportService.generatePersonalBestsReport(_selectedSwimmer!, events);
                final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
                await Printing.layoutPdf(
                  onLayout: (format) async => pdfBytes,
                  name: '${_selectedSwimmer!.firstName}_${_selectedSwimmer!.surname}_${dateStr}_personal_bests_report',
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCertificateSelectionDialog() async {
    final pbs = await _dbHelper.getPBsBySwimmer(_selectedSwimmer!.id!);
    if (pbs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Personal Bests found.')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select PB for Certificate'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pbs.length,
            itemBuilder: (context, index) {
              final pb = pbs[index];
              return ListTile(
                title: Text('${pb.distance}m ${pb.stroke} (${pb.course})'),
                subtitle: Text('Time: ${pb.formattedTime} @ ${pb.meetTitle ?? "Unknown Meet"}'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndShareCertificate(pb);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _generateAndShareCertificate(SwimEvent pb) async {
    final screenshotController = ScreenshotController();
    
    // Create the certificate off-screen
    final certificate = RepaintBoundary(
      child: PBCertificate(swimmer: _selectedSwimmer!, event: pb),
    );

    // Wait a bit for it to build
    await Future.delayed(const Duration(milliseconds: 100));
    
    final imageBytes = await screenshotController.captureFromWidget(
      certificate,
      delay: const Duration(milliseconds: 50),
      context: context,
    );

    final pdfBytes = await ReportService.generateCertificatePdf(imageBytes);
    final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${_selectedSwimmer!.firstName}_${_selectedSwimmer!.surname}_${dateStr}_pb_certificate_${pb.distance}m_${pb.stroke}',
    );
  }
}
