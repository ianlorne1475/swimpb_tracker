import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/qualifying_time.dart';
import '../theme/app_theme.dart';
import 'swim_stroke_icon.dart';

class PBCard extends StatelessWidget {
  final SwimEvent event;
  final List<QualifyingTime> metStandards;
  final QualifyingTime? targetStandard;
  final int? rank;
  final bool showQTLabel;

  const PBCard({
    super.key, 
    required this.event,
    this.metStandards = const [],
    this.targetStandard,
    this.rank,
    this.showQTLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = event.date != null 
        ? DateFormat('d MMM yyyy').format(DateTime.parse(event.date!))
        : 'UNKNOWN';

    final hasQTime = metStandards.isNotEmpty;

    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.border : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _getStrokeIcon(event.stroke),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event.distance}m ${event.stroke}'.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                event.formattedTime,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.course ?? '',
                                style: TextStyle(
                                fontSize: 11,
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (targetStandard != null) _buildDeltaTag(context),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.meetTitle ?? 'UNKNOWN MEET',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (targetStandard != null && showQTLabel)
                        Text(
                          'Target: ${formatTime(targetStandard!.timeMs)} (${targetStandard!.standardName})',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.accent : Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (rank != null)
            Positioned(
              top: -8,
              left: -8,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                  fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (hasQTime)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.8), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'QT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.amber : Colors.amber.shade900,
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

  Widget _buildDeltaTag(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deltaMs = event.timeMs - targetStandard!.timeMs;
    final isFaster = deltaMs <= 0;
    final deltaSeconds = deltaMs.abs() / 1000;
    
    final color = isFaster ? AppColors.accent : AppColors.error;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFaster ? Icons.trending_down : Icons.trending_up,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isFaster ? '-' : '+'}${deltaSeconds.toStringAsFixed(2)}s',
            style: TextStyle(
            fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStrokeIcon(String stroke) {
    return SwimStrokeIcon(
      stroke: SwimStrokeIcon.fromString(stroke),
      size: 18,
      color: AppColors.primary,
    );
  }

  static String formatTime(int timeMs) {
    final duration = Duration(milliseconds: timeMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hundredths = (timeMs % 1000) ~/ 10;
    
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
    } else {
      return '$seconds.${hundredths.toString().padLeft(2, '0')}';
    }
  }
}
