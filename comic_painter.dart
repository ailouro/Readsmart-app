import 'package:flutter/material.dart';
import 'dart:math' as math;

class ComicSunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height);
    
    // Background color (Red)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFD32F2F));

    // Sunburst rays (Yellow)
    final paint = Paint()..color = const Color(0xFFFFD54F);
    const int numRays = 16;
    const double angleStep = (2 * math.pi) / numRays;
    
    for (int i = 0; i < numRays; i += 2) {
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + radius * math.cos(i * angleStep),
        center.dy + radius * math.sin(i * angleStep),
      );
      path.lineTo(
        center.dx + radius * math.cos((i + 1) * angleStep),
        center.dy + radius * math.sin((i + 1) * angleStep),
      );
      path.close();
      canvas.drawPath(path, paint);
    }
    
    // Optional: Halftone dots overlay
    final dotPaint = Paint()..color = Colors.black.withOpacity(0.1);
    for (double y = 0; y < size.height; y += 20) {
      for (double x = 0; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
