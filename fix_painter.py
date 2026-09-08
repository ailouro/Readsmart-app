with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# I will just define ComicDotsPainter
widgets = '''
class ComicDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background color (Red)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFD32F2F));

    // Halftone dots overlay (Darker red/black dots)
    final dotPaint = Paint()..color = const Color(0xFFB71C1C).withValues(alpha: 0.6);
    for (double y = 0; y < size.height; y += 20) {
      for (double x = 0; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
'''
# Append ComicDotsPainter
text = text + '\n' + widgets

# Also check if ComicSunburstPainter is still there, I can just leave it there or remove it.
# Actually I'll just append ComicDotsPainter!

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Added ComicDotsPainter")
