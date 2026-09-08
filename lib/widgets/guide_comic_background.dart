import 'dart:math' as math;
import 'package:flutter/material.dart';

class GuideComicBackground extends StatelessWidget {
  final Widget child;
  const GuideComicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _GuideComicPainter())),
        // Add clouds at the bottom
        Positioned(
          bottom: -10,
          right: -20,
          child: _BottomRightCloud(width: 280, height: 120),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GuideComicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Fill entire background with Grey
    final greyPaint = Paint()..color = const Color(0xFFB0B0B0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), greyPaint);

    // 2. Define the jagged path
    final path = Path();
    path.moveTo(0, 0); // Start at top left
    path.lineTo(w * 0.45, 0); // Top edge jagged start
    path.lineTo(w * 0.28, h * 0.08);
    path.lineTo(w * 0.38, h * 0.15);
    path.lineTo(w * 0.15, h * 0.25);
    path.lineTo(w * 0.12, h * 0.40);
    path.lineTo(w * 0.22, h * 0.65);
    path.lineTo(w * 0.14, h * 0.70);
    path.lineTo(w * 0.32, h * 0.80);
    path.lineTo(w * 0.26, h * 0.90);
    path.lineTo(w * 0.45, h); // Bottom edge
    path.lineTo(0, h);
    path.close();

    // 3. Draw white background for jagged edge
    final whitePaint = Paint()..color = Colors.white;
    final blackStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeJoin = StrokeJoin.round;

    // Draw the thick black border and white fill for the jagged path
    canvas.drawPath(path, whitePaint);
    canvas.drawPath(path, blackStroke);

    // 4. Define the inner jagged path for the colored areas (shrink slightly)
    final innerPath = Path();
    innerPath.moveTo(0, 0);
    innerPath.lineTo(w * 0.45 - 25, 0);
    innerPath.lineTo(w * 0.28 - 25, h * 0.08);
    innerPath.lineTo(w * 0.38 - 25, h * 0.15);
    innerPath.lineTo(w * 0.15 - 25, h * 0.25);
    innerPath.lineTo(0, h * 0.22); // Split point for purple vs cyan
    innerPath.lineTo(0, 0);
    innerPath.close();

    final innerPathBottom = Path();
    innerPathBottom.moveTo(0, h * 0.22); // Split point
    innerPathBottom.lineTo(w * 0.15 - 25, h * 0.25);
    innerPathBottom.lineTo(w * 0.12 - 25, h * 0.40);
    innerPathBottom.lineTo(w * 0.22 - 25, h * 0.65);
    innerPathBottom.lineTo(w * 0.14 - 25, h * 0.70);
    innerPathBottom.lineTo(w * 0.32 - 25, h * 0.80);
    innerPathBottom.lineTo(w * 0.26 - 25, h * 0.90);
    innerPathBottom.lineTo(w * 0.45 - 25, h);
    innerPathBottom.lineTo(0, h);
    innerPathBottom.close();

    // 5. Draw purple sunburst in innerPath (Top Left)
    canvas.save();
    canvas.clipPath(innerPath);
    _drawSunburst(
      canvas,
      size,
      const Color(0xFF8B88DE),
      const Color(0xFF9B98E9),
      const Offset(0, 0),
    );
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    );
    canvas.restore();

    // 6. Draw cyan sunburst in innerPathBottom (Bottom Left)
    canvas.save();
    canvas.clipPath(innerPathBottom);
    _drawSunburst(
      canvas,
      size,
      const Color(0xFF67D8E7),
      const Color(0xFF7DE4F2),
      Offset(0, h * 0.6),
    );
    canvas.drawPath(
      innerPathBottom,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    );
    canvas.restore();
  }

  void _drawSunburst(
    Canvas canvas,
    Size size,
    Color color1,
    Color color2,
    Offset center,
  ) {
    canvas.drawPaint(Paint()..color = color1);
    final paint = Paint()..color = color2;
    const int rays = 24;
    final double angleStep = (2 * math.pi) / rays;
    final radius = math.max(size.width, size.height) * 2;
    for (int i = 0; i < rays; i += 2) {
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        i * angleStep,
        angleStep,
        false,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomRightCloud extends StatelessWidget {
  final double width;
  final double height;
  const _BottomRightCloud({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _CloudPainter()),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height);
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.7,
      size.width * 0.3,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.4,
      size.width * 0.6,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.3,
      size.width * 0.95,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 1.1,
      size.height * 0.8,
      size.width,
      size.height,
    );
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
