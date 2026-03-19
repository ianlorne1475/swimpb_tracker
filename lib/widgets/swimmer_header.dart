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
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? AppColors.border : AppColors.lightBorder,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: swimmer.photoPath != null && File(swimmer.photoPath!).existsSync()
                          ? Image.file(File(swimmer.photoPath!), fit: BoxFit.cover)
                          : Container(
                              color: isDark ? AppColors.surface : AppColors.lightBackground,
                              child: Icon(
                                Icons.person, 
                                size: 36, 
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => swimmers.map((s) => PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Text(_getFlagEmoji(s.nationality), style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 12),
                                Text(s.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getFlagEmoji(swimmer.nationality),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${swimmer.club ?? "No Club"}  •  ${swimmer.gender.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded, 
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary, 
                      size: 18
                    ),
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.background : AppColors.lightBackground,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatPill(context, '${swimmer.calculateAgeAtEndYear()} yrs', Icons.cake_outlined, isDark),
                        _buildStatPill(context, '$resultCount Races', Icons.analytics_outlined, isDark),
                        _buildStatPill(context, '$scmCount SCM', Icons.pool_rounded, isDark),
                        _buildStatPill(context, '$lcmCount LCM', Icons.pool_rounded, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onAddMeet,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('ADD MEET'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primary : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(0, 40),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
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
