with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = "import 'dart:math' as math;\n" + text.replace("import 'dart:math' as math;\n", "")

widgets = '''

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SkewedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  
  const SkewedButton({Key? key, required this.text, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Transform(
        transform: Matrix4.skewX(-0.3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Transform(
            transform: Matrix4.skewX(0.3),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
'''

# Remove any old appended stuff
text = text.split('class ComicSunburstPainter')[0]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text + widgets)

print("Done")
