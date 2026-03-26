import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/qualifying_time.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

class QualifyingTimesScreen extends StatefulWidget {
  const QualifyingTimesScreen({super.key});

  @override
  State<QualifyingTimesScreen> createState() => _QualifyingTimesScreenState();
}

class _QualifyingTimesScreenState extends State<QualifyingTimesScreen> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _genderController;
  late TabController _strokeController;
  
  String _selectedGender = 'Female';
  String _selectedStroke = 'Butterfly';
  List<QualifyingTime> _qualifyingTimes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _genderController = TabController(length: 2, vsync: this);
    _strokeController = TabController(length: 5, vsync: this);
    
    _genderController.addListener(() {
      if (!_genderController.indexIsChanging) {
        setState(() {
          _selectedGender = _genderController.index == 0 ? 'Female' : 'Male';
          _loadData();
        });
      }
    });

    _strokeController.addListener(() {
      if (!_strokeController.indexIsChanging) {
        const strokes = ['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'];
        setState(() {
          _selectedStroke = strokes[_strokeController.index];
          _loadData();
        });
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _genderController.dispose();
    _strokeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final times = await _dbHelper.getQualifyingTimes(gender: _selectedGender);
    setState(() {
      _qualifyingTimes = times.where((qt) => qt.stroke == _selectedStroke).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QUALIFICATION TIMES',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildToggleCard(
                  isDark,
                  TabBar(
                    controller: _genderController,
                    indicator: _tabIndicator(isDark),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                    unselectedLabelColor: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.female_rounded, size: 14), SizedBox(width: 4), Text('FEMALE')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.male_rounded, size: 14), SizedBox(width: 4), Text('MALE')])),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _buildToggleCard(
                  isDark,
                  TabBar(
                    controller: _strokeController,
                    isScrollable: false,
                    indicator: _tabIndicator(isDark),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                    unselectedLabelColor: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 9),
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(text: 'FLY'),
                      Tab(text: 'BACK'),
                      Tab(text: 'BREAST'),
                      Tab(text: 'FREE'),
                      Tab(text: 'IM'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qualifyingTimes.isEmpty
              ? const Center(child: Text('No standards found.'))
              : _buildStandardsList(),
    );
  }

  Decoration _tabIndicator(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  Widget _buildToggleCard(bool isDark, Widget child) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.surface 
            : AppColors.lightBorder.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildStandardsList() {
    // Group by stroke
    final Map<String, List<QualifyingTime>> grouped = {};
    for (var qt in _qualifyingTimes) {
      final key = '${qt.distance}m ${qt.stroke}';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(qt);
    }

    // Sort keys by standard stroke order
    final sortedKeys = grouped.keys.toList();
    const strokeOrder = ['Butterfly', 'Backstroke', 'Breaststroke', 'Freestyle', 'IM'];
    
    sortedKeys.sort((a, b) {
      final strokeA = a.split(' ').last;
      final strokeB = b.split(' ').last;
      final distA = int.tryParse(a.split('m').first) ?? 0;
      final distB = int.tryParse(b.split('m').first) ?? 0;

      final orderA = strokeOrder.indexOf(strokeA);
      final orderB = strokeOrder.indexOf(strokeB);

      if (orderA != orderB) return orderA.compareTo(orderB);
      return distA.compareTo(distB);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final times = grouped[key]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? AppColors.border : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Text(
                  key.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < 4; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: i < times.length 
                                ? _buildAgeTile(times[i], isDark)
                                : const SizedBox(),
                            ),
                          ),
                      ],
                    ),
                    if (times.length > 4)
                      Row(
                        children: [
                          for (int i = 4; i < 8; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: i < times.length 
                                  ? _buildAgeTile(times[i], isDark)
                                  : const SizedBox(),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgeTile(QualifyingTime qt, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatAge(qt.ageMin, qt.ageMax),
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            TimeUtils.formatTime(qt.timeMs),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatAge(int min, int max) {
    if (min == 7 && max == 8) return 'Under 9';
    if (min == max) return 'Age $min';
    if (max >= 99) return 'Age $min+';
    return '$min-$max';
  }
}
