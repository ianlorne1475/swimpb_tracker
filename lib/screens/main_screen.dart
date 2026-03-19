import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../database_helper.dart';
import '../models/swimmer.dart';
import 'tabs/pb_tab.dart';
import 'tabs/recent_bests_tab.dart';
import 'tabs/progression_tab.dart';
import 'tabs/meets_tab.dart';
import '../widgets/swimmer_dialog.dart';
import '../widgets/add_meet_dialog.dart';
import '../widgets/swimmer_header.dart';
import '../theme/app_theme.dart';
import '../services/bulk_import_service.dart';
import '../services/bulk_export_service.dart';
import '../services/qualifying_times_service.dart';
import '../services/theme_service.dart';
import '../widgets/daily_goal_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BulkImportService _importService = BulkImportService();
  
  List<Swimmer> _swimmers = [];
  Swimmer? _selectedSwimmer;
  int _meetCount = 0;
  int _scmMeetCount = 0;
  int _lcmMeetCount = 0;
  int _resultCount = 0;
  
  bool _showTooltip = false;
  String _tooltipText = '';
  Timer? _tooltipTimer;

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
      _showTooltip = true;
    });
    _tooltipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showTooltip = false);
      }
    });
  }


  Future<void> _loadSwimmers() async {
    final swimmers = await _dbHelper.getSwimmers();
    setState(() {
      _swimmers = swimmers;
      if (_selectedSwimmer != null) {
        // Update the selected swimmer object with new data from DB
        try {
          _selectedSwimmer = _swimmers.firstWhere((s) => s.id == _selectedSwimmer!.id);
        } catch (e) {
          _selectedSwimmer = null;
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
      });
    }
  }

  Future<String?> _showCourseSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Course Type'),
        content: const Text('Are these results from a Short Course (25m) or Long Course (50m) pool?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'SCM'),
            child: const Text('SCM (25m)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'LCM'),
            child: const Text('LCM (50m)'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkImport() async {
    if (_selectedSwimmer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a swimmer first.')),
      );
      return;
    }
    
    try {
      final course = await _showCourseSelectionDialog();
      if (course == null) return;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final count = await _importService.importFromFile(
          file, 
          targetSwimmerId: _selectedSwimmer?.id,
          course: course,
        );
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import completed: $count events added/updated ($course)!')),
        );
        
        _loadSwimmerData();
        setState(() {}); // Force rebuild tabs
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _handleDeleteRaceData() async {
    Swimmer? targetSwimmer = _selectedSwimmer;
    String targetCourse = 'SCM';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Race Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will delete all race results for the selected swimmer and course type. This cannot be undone.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<Swimmer>(
                value: targetSwimmer,
                decoration: const InputDecoration(labelText: 'Select Swimmer'),
                items: _swimmers.map((s) => DropdownMenuItem(value: s, child: Text(s.fullName))).toList(),
                onChanged: (s) => setDialogState(() => targetSwimmer = s),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: targetCourse,
                decoration: const InputDecoration(labelText: 'Select Course'),
                items: ['SCM', 'LCM'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => targetCourse = v!),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $targetCourse results for ${targetSwimmer!.fullName}.')),
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        title: const Text('SwimPB Tracker'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.settings_outlined, 
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.textSecondary 
                  : AppColors.lightTextSecondary,
            ),
            onSelected: (value) async {
              if (value == 'import') {
                _handleBulkImport();
              } else if (value == 'add_swimmer') {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const SwimmerDialog(),
                );
                if (result == true) {
                  _loadSwimmers();
                }
              } else if (value == 'delete_swimmer') {
                if (_selectedSwimmer == null) return;
                
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Swimmer'),
                    content: Text('Are you sure you want to delete ${_selectedSwimmer!.fullName}? All their times and meets will be lost.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _dbHelper.deleteSwimmer(_selectedSwimmer!.id!);
                  setState(() {
                    _selectedSwimmer = null;
                    _meetCount = 0;
                  });
                  _loadSwimmers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Swimmer deleted.')),
                    );
                  }
                }
              } else if (value == 'clear_all') {
                _handleClearAllData();
              } else if (value == 'delete_race_data') {
                _handleDeleteRaceData();
              } else if (value == 'toggle_theme') {
                ThemeService().toggleTheme();
              } else if (value == 'export') {
                _handleBulkExport();
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
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 8),
                    Text('Bulk Import'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline, size: 20),
                    SizedBox(width: 8),
                    Text('Bulk Export'),
                  ],
                ),
              ),
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
              const PopupMenuDivider(),
              if (_selectedSwimmer != null)
                const PopupMenuItem(
                  value: 'delete_swimmer',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Current Swimmer'),
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
                  if (result == true) {
                    _loadSwimmers();
                    _loadSwimmerData();
                  }
                },
                onAddMeet: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) => const AddMeetDialog(),
                  );
                  if (result == true) {
                    _loadSwimmerData();
                  }
                },
              ),
            
            // Daily Goal (Persistent & Daily Reset)
            const DailyGoalWidget(),
            
            if (_selectedSwimmer == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppColors.surface : AppColors.lightBorder.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.pool_rounded,
                              size: 64,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'READY TO DIVE IN?',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 20,
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
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (context) => const SwimmerDialog(),
                              );
                              if (result == true) {
                                _loadSwimmers();
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
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.show_chart, size: 14), SizedBox(width: 4), Text('PROG.')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.description_outlined, size: 14), SizedBox(width: 4), Text('HISTORY')])),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (_selectedSwimmer != null)
                    PersonalBestsTab(swimmerId: _selectedSwimmer!.id!)
                  else
                    const Center(child: Text('Add a swimmer to see PBs')),
                  if (_selectedSwimmer != null)
                    RecentBestsTab(swimmerId: _selectedSwimmer!.id!)
                  else
                    const Center(child: Text('Add a swimmer to see results')),
                  if (_selectedSwimmer != null)
                    ProgressionTab(swimmerId: _selectedSwimmer!.id!)
                  else
                    const Center(child: Text('Add a swimmer to see progression')),
                  if (_selectedSwimmer != null)
                    MeetsTab(swimmerId: _selectedSwimmer!.id!)
                  else
                    const Center(child: Text('Add a swimmer to see history')),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
      if (_showTooltip)
        Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: AnimatedOpacity(
                opacity: _showTooltip ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.border 
                        : AppColors.lightBorder,
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
    );
  }

  void _handleBulkExport() async {
    Swimmer? exportSwimmer = _selectedSwimmer;
    String exportCourse = 'SCM';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export Swimmer Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Swimmer>(
                value: exportSwimmer,
                decoration: const InputDecoration(labelText: 'Swimmer'),
                items: _swimmers.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.fullName),
                )).toList(),
                onChanged: (val) => setDialogState(() => exportSwimmer = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: exportCourse,
                decoration: const InputDecoration(labelText: 'Course'),
                items: const [
                  DropdownMenuItem(value: 'SCM', child: Text('Short Course (25m)')),
                  DropdownMenuItem(value: 'LCM', child: Text('Long Course (50m)')),
                ],
                onChanged: (val) => setDialogState(() => exportCourse = val!),
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
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );

    if (result != true || exportSwimmer == null) return;
    final Swimmer swimmerToExport = exportSwimmer!;

    try {
      final String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final String fileName = '${swimmerToExport.surname}_${swimmerToExport.firstName}_$exportCourse\_$dateStr.csv'
          .replaceAll(' ', '_')
          .toLowerCase();

      final exportService = BulkExportService();
      final String csvContent = await exportService.getSwimmerCsvContent(swimmerToExport.id!, exportCourse);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select export location',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported to $outputFile')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
