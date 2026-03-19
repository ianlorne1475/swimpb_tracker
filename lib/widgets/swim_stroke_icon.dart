import 'package:flutter/material.dart';
import 'dart:math' as math;

enum SwimStroke { butterfly, backstroke, breaststroke, freestyle, medley }

class SwimStrokeIcon extends StatelessWidget {
  final SwimStroke stroke;
  final double size;
  final Color? color;

  const SwimStrokeIcon({
    super.key,
    required this.stroke,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StrokePainter(stroke, iconColor),
      ),
    );
  }

  static SwimStroke fromString(String strokeName) {
    final name = strokeName.toLowerCase();
    if (name.contains('butterfly')) return SwimStroke.butterfly;
    if (name.contains('backstroke')) return SwimStroke.backstroke;
    if (name.contains('breaststroke')) return SwimStroke.breaststroke;
    if (name.contains('freestyle')) return SwimStroke.freestyle;
    if (name.contains('individual medley') || name == 'im') return SwimStroke.medley;
    return SwimStroke.freestyle; // Default
  }
}

class _StrokePainter extends CustomPainter {
  final SwimStroke stroke;
  final Color color;

  _StrokePainter(this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (stroke) {
      case SwimStroke.butterfly:
        _drawButterfly(canvas, size, paint, fillPaint);
        break;
      case SwimStroke.backstroke:
        _drawBackstroke(canvas, size, paint, fillPaint);
        break;
      case SwimStroke.breaststroke:
        _drawBreaststroke(canvas, size, paint, fillPaint);
        break;
      case SwimStroke.freestyle:
        _drawFreestyle(canvas, size, paint, fillPaint);
        break;
      case SwimStroke.medley:
        _drawMedley(canvas, size, paint, fillPaint);
        break;
    }
  }

  void _drawButterfly(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final path = Path();
    // Two symmetrical wings
    path.moveTo(size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.1, size.width * 0.1, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.9, size.width * 0.5, size.height * 0.7);

    path.moveTo(size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.1, size.width * 0.9, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.9, size.width * 0.5, size.height * 0.7);

    canvas.drawPath(path, fillPaint);
    // Head
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), size.width * 0.12, fillPaint);
  }

  void _drawBackstroke(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    // Water line
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), paint);
    
    // Swimmer silhouette (head and one arm up)
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.55), size.width * 0.15, fillPaint);
    
    final armPath = Path();
    armPath.moveTo(size.width * 0.45, size.height * 0.6);
    armPath.quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width * 0.6, 0);
    canvas.drawPath(armPath, paint);
  }

  void _drawBreaststroke(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    // Symmetrical arm sweep
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(0, size.height * 0.1, 0, size.height * 0.5);
    path.quadraticBezierTo(0, size.height * 0.8, size.width * 0.5, size.height * 0.9);
    path.quadraticBezierTo(size.width, size.height * 0.8, size.width, size.height * 0.5);
    path.quadraticBezierTo(size.width, size.height * 0.1, size.width * 0.5, size.height * 0.4);
    
    canvas.drawPath(path, paint);
    // Head
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.25), size.width * 0.15, fillPaint);
  }

  void _drawFreestyle(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    // Water line
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), paint);
    
    // Swimmer silhouette
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.55), size.width * 0.15, fillPaint);
    
    final armPath = Path();
    armPath.moveTo(size.width * 0.35, size.height * 0.5);
    armPath.quadraticBezierTo(size.width * 0.1, size.height * 0.1, size.width * 0.6, size.height * 0.1);
    canvas.drawPath(armPath, paint);

    final secondArmPath = Path();
    secondArmPath.moveTo(size.width * 0.45, size.height * 0.6);
    secondArmPath.lineTo(size.width * 0.8, size.height * 0.8);
    canvas.drawPath(secondArmPath, paint);
  }

  void _drawMedley(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    // Segmented circle (4 quadrants)
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    
    canvas.drawArc(rect, 0, math.pi / 2 - 0.2, true, fillPaint);
    canvas.drawArc(rect, math.pi / 2, math.pi / 2 - 0.2, true, fillPaint);
    canvas.drawArc(rect, math.pi, math.pi / 2 - 0.2, true, fillPaint);
    canvas.drawArc(rect, 3 * math.pi / 2, math.pi / 2 - 0.2, true, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
