import 'dart:io';
import 'package:flutter/material.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';

class SwimmerHeader extends StatelessWidget {
  final Swimmer swimmer;
  final List<Swimmer> swimmers;
  final int meetCount;
  final int scmCount;
  final int lcmCount;
  final int resultCount;
  final Function(Swimmer) onSwimmerSelected;
  final VoidCallback onEdit;
  final VoidCallback onAddMeet;

  const SwimmerHeader({
    super.key,
    required this.swimmer,
    required this.swimmers,
    required this.meetCount,
    required this.scmCount,
    required this.lcmCount,
    required this.resultCount,
    required this.onSwimmerSelected,
    required this.onEdit,
    required this.onAddMeet,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Subtle background decoration
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.pool_rounded,
                  size: 120,
                  color: (isDark ? Colors.white : AppColors.primary).withOpacity(0.03),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: isDark ? AppColors.border : AppColors.lightBorder,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: swimmer.photoPath != null && File(swimmer.photoPath!).existsSync()
                                    ? Image.file(File(swimmer.photoPath!), fit: BoxFit.cover)
                                    : Container(
                                        color: isDark ? AppColors.background : AppColors.lightBackground,
                                        child: Icon(
                                          Icons.person_rounded, 
                                          size: 40, 
                                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PopupMenuButton<Swimmer>(
                                    onSelected: onSwimmerSelected,
                                    padding: EdgeInsets.zero,
                                    position: PopupMenuPosition.under,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 12,
                                    itemBuilder: (context) => swimmers.map((s) => PopupMenuItem(
                                      value: s,
                                      child: Row(
                                        children: [
                                          Text(_getFlagEmoji(s.nationality), style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 12),
                                          Text(s.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    )).toList(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            swimmer.fullName,
                                            style: TextStyle(
                                              fontSize: isWide ? 28 : 24,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.8,
                                              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 22,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getFlagEmoji(swimmer.nationality),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${swimmer.club ?? "Unattached"}  •  ${swimmer.gender.toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isWide) ...[
                              ElevatedButton.icon(
                                onPressed: onAddMeet,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text('ADD MEET'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onEdit,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? AppColors.border : AppColors.lightBorder),
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded, 
                                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary, 
                                    size: 20
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatPill(context, '${swimmer.calculateAgeAtEndYear()} YRS', Icons.cake_rounded, isDark),
                                  _buildStatPill(context, '$resultCount RACES', Icons.analytics_rounded, isDark),
                                  _buildStatPill(context, '$scmCount SCM', Icons.waves_rounded, isDark),
                                  _buildStatPill(context, '$lcmCount LCM', Icons.waves_rounded, isDark),
                                ],
                              ),
                            ),
                            if (!isWide) ...[
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: onAddMeet,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text('ADD MEET'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: AppColors.primary.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.background : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final int first = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
