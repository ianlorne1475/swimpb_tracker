import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class PBCertificate extends StatelessWidget {
  final Swimmer swimmer;
  final SwimEvent event;

  const PBCertificate({
    super.key,
    required this.swimmer,
    required this.event,
  });

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

  @override
  Widget build(BuildContext context) {
    final dateStr = event.formattedDate;
    
    return Container(
      width: 600,
      height: 440, // Increased for breathing room
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A), // Dark Navy
            const Color(0xFF1E293B), // Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFC5A059), // Metallic Gold
          width: 12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner Decorations (Glow)
          ...List.generate(4, (i) => Positioned(
            top: (i < 2) ? 10 : null,
            bottom: (i >= 2) ? 10 : null,
            left: (i % 2 == 0) ? 10 : null,
            right: (i % 2 != 0) ? 10 : null,
            child: Icon(
              Icons.star, 
              color: const Color(0xFFC5A059).withOpacity(0.3), 
              size: 40
            ),
          )),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 24.0), // Reduced vertical padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CERTIFICATE of ACHIEVEMENT',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Serif',
                    fontSize: 22, // Back to 22
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC5A059),
                    letterSpacing: 2, // Slightly reduced
                  ),
                ),
                const SizedBox(height: 8), // Reduced gap
                Container(
                  height: 1,
                  width: 80,
                  color: const Color(0xFFC5A059).withOpacity(0.5),
                ),
                const SizedBox(height: 8), // Reduced gap
                const Text(
                  'PERSONAL BEST RECORD',
                  style: TextStyle(
                    fontSize: 11, // Reduced font size
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 20), // Reduced gap
                const Text(
                  'This is to certify that',
                  style: TextStyle(
                    fontSize: 13, 
                    color: Colors.white60, 
                    fontStyle: FontStyle.italic
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  swimmer.fullName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28, // Slightly reduced
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12), // Reduced gap
                const Text(
                  'has established an outstanding performance in',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.distance}m ${event.stroke} (${event.course})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC5A059),
                  ),
                ),
                const SizedBox(height: 12), // Reduced gap
                Text(
                  'OFFICIAL RECORD TIME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.formattedTime,
                  style: const TextStyle(
                    fontSize: 40, // Slightly reduced
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16), // Fixed gap instead of Spacer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (event.meetTitle ?? "Unknown Meet").toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 10, 
                              color: Colors.white38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Text(
                          'SWIMPB TRACKER',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFC5A059).withOpacity(0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Image.asset(
                          'assets/icon/icon.png',
                          width: 32,
                          height: 32,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.pool, 
                            size: 32, 
                            color: Color(0xFFC5A059)
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
