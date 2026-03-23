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
import 'settings_screen.dart';

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
  final ValueNotifier<List<Swimmer>> _swimmersNotifier = ValueNotifier<List<Swimmer>>([]);
  final ValueNotifier<Set<int>> _swimmerIdsWithResultsNotifier = ValueNotifier<Set<int>>({});
  
  int _selectedDistance = 50;
  String _selectedStroke = 'Butterfly';
  String _selectedCourse = 'LCM';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _loadSwimmers();
    QualifyingTimesService().seedSnag2026Female();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _swimmersNotifier.dispose();
    _swimmerIdsWithResultsNotifier.dispose();
    // _searchController.dispose(); // This line is commented out because _searchController is not declared in the provided code.
    super.dispose();
  }



  Future<void> _loadSwimmers({int? targetId}) async {
    final swimmers = await _dbHelper.getSwimmers();
    final idsWithResults = await _dbHelper.getSwimmerIdsWithResults();
    _swimmersNotifier.value = swimmers;
    _swimmerIdsWithResultsNotifier.value = idsWithResults;
    
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
      final idsWithResults = await _dbHelper.getSwimmerIdsWithResults();
      _swimmerIdsWithResultsNotifier.value = idsWithResults;
      
      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _meetCount = count;
              _scmMeetCount = scmCount;
              _lcmMeetCount = lcmCount;
              _resultCount = eventCount;
              _refreshCounter++;
            });
          }
        });
      }
    }
  }

  
  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          swimmersNotifier: _swimmersNotifier,
          swimmerIdsWithResultsNotifier: _swimmerIdsWithResultsNotifier,
          selectedSwimmer: _selectedSwimmer,
          onAddSwimmer: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => const SwimmerDialog(),
            );
            if (result is int) {
              _loadSwimmers(targetId: result);
            }
          },
          onImportData: _handleImportData,
          onExportData: _handleExportData,
          onReports: _showReportsDialog,
          onDeleteRaceData: _handleDeleteRaceData,
          onClearAllData: _handleClearAllData,
          onDeleteSwimmer: (swimmer) async {
            await _dbHelper.deleteSwimmer(swimmer.id!);
            await _loadSwimmers();
            if (mounted) {
              setState(() {
                if (_selectedSwimmer?.id == swimmer.id) {
                  _selectedSwimmer = null;
                  _meetCount = 0;
                  _scmMeetCount = 0;
                  _lcmMeetCount = 0;
                  _resultCount = 0;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Swimmer ${swimmer.fullName} deleted.')),
              );
              
              if (_swimmersNotifier.value.isEmpty) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          },
        ),
      ),
    );
    _loadSwimmers(); // Final refresh when returning from settings
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


  Future<void> _handleDeleteRaceData(Swimmer? swimmer) async {
    Swimmer? targetSwimmer = swimmer ?? _selectedSwimmer;
    if (targetSwimmer == null) return;
    String targetCourse = 'All';

    await _dbHelper.deleteEventsBySwimmerAndCourse(targetSwimmer.id!, targetCourse);
    await _loadSwimmerData();
    setState(() {});
    if (mounted) {
      final message = targetCourse == 'All' 
          ? 'Deleted all results for ${targetSwimmer.fullName}.'
          : 'Deleted $targetCourse results for ${targetSwimmer.fullName}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleClearAllData() async {
    await _dbHelper.clearAllData();
    setState(() {
      _selectedSwimmer = null;
      _meetCount = 0;
      _scmMeetCount = 0;
      _lcmMeetCount = 0;
      _resultCount = 0;
    });
    await _loadSwimmers();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared successfully.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.textSecondary 
                    : AppColors.lightTextSecondary,
              ),
              onPressed: _openSettings,
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

    // NEW: Check most recent clubs from meet history
    final List<String?> recentClubs = [];
    for (var s in _swimmers) {
      recentClubs.add(await _dbHelper.getRecentClubForSwimmer(s.id!));
    }
    
    final nonNullClubs = recentClubs.where((c) => c != null && c!.isNotEmpty).toSet();
    final bool allSameTeam = nonNullClubs.length == 1 && recentClubs.every((c) => c == nonNullClubs.first);
    
    String exportType = allSameTeam ? 'Team' : 'Individual'; 
    Swimmer? exportSwimmer = _selectedSwimmer;
    String teamName = allSameTeam ? nonNullClubs.first! : 'Multiple Swimmers';

    final String ddmmyyyy = DateFormat('ddMMyyyy').format(DateTime.now());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(allSameTeam ? 'Team Data Export' : 'Multiple Swimmers Data Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(allSameTeam 
                ? 'All swimmers belong to "${nonNullClubs.first}".'
                : 'Variation in swimmer teams detected.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: exportType,
                decoration: const InputDecoration(labelText: 'Export Type'),
                items: [
                  const DropdownMenuItem(value: 'Individual', child: Text('Individual Swimmer Data Export')),
                  DropdownMenuItem(
                    value: 'Team', 
                    child: Text(allSameTeam ? 'Team Data Export' : 'Multiple Swimmers Data Export'),
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
                
                final pdfBytes = await ReportService().generateNationalQTReport(_selectedSwimmer!, events, standards);
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
                
                final pdfBytes = await ReportService().generatePersonalGoalsReport(_selectedSwimmer!, goals, allEvents);
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
                final pdfBytes = await ReportService().generatePersonalBestsReport(_selectedSwimmer!, events);
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

    final pdfBytes = await ReportService().generateCertificatePdf(imageBytes);
    final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${_selectedSwimmer!.firstName}_${_selectedSwimmer!.surname}_${dateStr}_pb_certificate_${pb.distance}m_${pb.stroke}',
    );
  }
}
