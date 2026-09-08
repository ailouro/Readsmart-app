import 'package:flutter/material.dart';

class StoryComicBackground extends StatefulWidget {
  final Widget child;
  const StoryComicBackground({super.key, required this.child});

  @override
  State<StoryComicBackground> createState() => _StoryComicBackgroundState();
}

class _StoryComicBackgroundState extends State<StoryComicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _StoryComicPainter(animationValue: _controller.value),
              );
            },
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _StoryComicPainter extends CustomPainter {
  final double animationValue;

  _StoryComicPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Red base background
    final redPaint = Paint()..color = const Color(0xFFD32F2F);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), redPaint);

    // 2. Halftone dots (orange)
    final dotPaint = Paint()..color = const Color(0xFFE64A19).withOpacity(0.6);
    const double spacing = 14.0;
    const double dotSize = 4.0;
    
    // Shift the dots based on animation value
    double shiftX = animationValue * (spacing * 2);
    double shiftY = animationValue * (spacing * 2);

    for (double y = -spacing * 2; y < h + spacing * 2; y += spacing) {
      for (double x = -spacing * 2; x < w + spacing * 2; x += spacing) {
        double offsetX = ((y - shiftY) % (spacing * 2) < spacing) ? 0 : spacing / 2;
        canvas.drawCircle(Offset(x + offsetX + shiftX, y + shiftY), dotSize, dotPaint);
      }
    }

    // 3. Yellow jagged lightning flash across the top middle
    final yellowPath = Path();
    yellowPath.moveTo(0, h * 0.15);
    yellowPath.lineTo(w * 0.4, h * 0.1);
    yellowPath.lineTo(w * 0.35, h * 0.22);
    yellowPath.lineTo(w, h * 0.12);
    yellowPath.lineTo(w, h * 0.25);
    yellowPath.lineTo(w * 0.6, h * 0.28);
    yellowPath.lineTo(w * 0.65, h * 0.4);
    yellowPath.lineTo(0, h * 0.32);
    yellowPath.close();

    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFDE047));
    canvas.drawPath(
      yellowPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 4. White jagged explosion at the bottom
    final bottomPath = Path();
    bottomPath.moveTo(0, h);
    bottomPath.lineTo(0, h * 0.85);
    bottomPath.lineTo(w * 0.25, h * 0.88);
    bottomPath.lineTo(w * 0.4, h * 0.82);
    bottomPath.lineTo(w * 0.6, h * 0.92);
    bottomPath.lineTo(w * 0.8, h * 0.83);
    bottomPath.lineTo(w, h * 0.9);
    bottomPath.lineTo(w, h);
    bottomPath.close();

    canvas.drawPath(bottomPath, Paint()..color = Colors.white);
    canvas.drawPath(
      bottomPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // 5. Dark grey jagged header at the top
    final topPath = Path();
    topPath.moveTo(0, 0);
    topPath.lineTo(w, 0);
    topPath.lineTo(w, h * 0.12);
    topPath.lineTo(w * 0.75, h * 0.08);
    topPath.lineTo(w * 0.5, h * 0.14);
    topPath.lineTo(w * 0.25, h * 0.09);
    topPath.lineTo(0, h * 0.13);
    topPath.close();

    canvas.drawPath(topPath, Paint()..color = const Color(0xFF2D2D2D));
    canvas.drawPath(
      topPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryComicPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}
