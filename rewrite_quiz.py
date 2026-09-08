import sys
import re

content = open('lib/screens/quiz_screen.dart', encoding='utf-8').read()

new_code = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Story Quiz", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 24, shadows: [Shadow(color: Colors.black45, offset: Offset(2,2), blurRadius: 4)])),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CustomPaint(
        painter: QuizBackgroundPainter(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 650;
              return Center(
                child: Container(
                  width: isDesktop ? 600 : constraints.maxWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _questions.isEmpty
                      ? const Center(child: Text("No quiz available for this story.", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          itemCount: _questions.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _questions.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 30),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A3B43),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 5,
                                  ),
                                  onPressed: _isSubmitting ? null : _submitQuiz,
                                  child: _isSubmitting
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          "Submit Answers",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                 .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05), duration: 800.ms),
                              );
                            }

                            var question = _questions[index];
                            List<dynamic> options = question['options'] ?? [];

                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12, width: 2)),
                              margin: const EdgeInsets.only(bottom: 20),
                              color: Colors.white.withOpacity(0.95),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${index + 1}. ${question['question_text']}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF2C246E),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    ...List.generate(options.length, (optIdx) {
                                      bool isSelected = _selectedAnswers[index] == optIdx;
                                      Widget tile = RadioListTile<int>(
                                        title: Text(
                                          options[optIdx].toString(),
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                            color: isSelected ? const Color(0xFF6A3B43) : Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                        value: optIdx,
                                        groupValue: _selectedAnswers[index],
                                        activeColor: const Color(0xFF9B40C9),
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedAnswers[index] = val!;
                                          });
                                        },
                                      );
                                      
                                      if (isSelected) {
                                        tile = tile.animate(key: ValueKey('opt_${index}_${optIdx}'))
                                          .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.03, 1.03), duration: 200.ms)
                                          .tint(color: const Color(0xFFDCA9F5).withOpacity(0.2));
                                      }
                                      return tile;
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class QuizBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background color (Light Purple)
    final bgPaint = Paint()..color = const Color(0xFFDCA9F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // 2. Top-right beige patch
    final pathBeige = Path();
    pathBeige.moveTo(size.width * 0.7, 0);
    pathBeige.quadraticBezierTo(size.width * 0.8, size.height * 0.1, size.width * 0.9, size.height * 0.05);
    pathBeige.quadraticBezierTo(size.width, size.height * 0.2, size.width, size.height * 0.25);
    pathBeige.lineTo(size.width, 0);
    pathBeige.close();
    canvas.drawPath(pathBeige, Paint()..color = const Color(0xFFF2EAE0));

    // Dark blue squiggly lines near top-right
    final paintSquiggle = Paint()
      ..color = const Color(0xFF2E4B75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final pathSquiggle = Path();
    pathSquiggle.moveTo(size.width * 0.75, 0);
    pathSquiggle.quadraticBezierTo(size.width * 0.8, size.height * 0.05, size.width * 0.85, size.height * 0.05);
    pathSquiggle.quadraticBezierTo(size.width * 0.9, size.height * 0.08, size.width * 0.92, size.height * 0.15);
    canvas.drawPath(pathSquiggle, paintSquiggle);

    final pathSquiggle2 = Path();
    pathSquiggle2.moveTo(size.width * 0.85, 0);
    pathSquiggle2.quadraticBezierTo(size.width * 0.9, size.height * 0.1, size.width * 0.98, size.height * 0.2);
    canvas.drawPath(pathSquiggle2, paintSquiggle);

    // 3. Top-left dark nested circles
    final centerTopLeft = Offset(size.width * 0.1, size.height * 0.1);
    // Outer dark gray
    canvas.drawCircle(centerTopLeft, size.width * 0.45, Paint()..color = const Color(0xFF4C4C54));
    // Inner navy blue
    canvas.drawCircle(centerTopLeft, size.width * 0.3, Paint()..color = const Color(0xFF2C246E));
    
    // Spiraling light purple/white lines inside the navy blue circle
    final spiralPaint = Paint()
      ..color = const Color(0xFF8672C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
       canvas.drawCircle(centerTopLeft, size.width * 0.06 * (i + 1), spiralPaint);
    }
    // Dots near top-left
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.04), 8, Paint()..color = const Color(0xFF8BA6B9));
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.06), 11, Paint()..color = const Color(0xFF8BA6B9));
    canvas.drawCircle(Offset(size.width * 0.33, size.height * 0.09), 6, Paint()..color = const Color(0xFF8BA6B9));

    // 4. Bottom-left concentric ovals (teal)
    final centerBottomLeft = Offset(size.width * 0.15, size.height * 0.9);
    final tealPaint = Paint()
      ..color = const Color(0xFF679B9B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < 6; i++) {
       canvas.drawOval(
           Rect.fromCenter(center: centerBottomLeft, width: size.width * 0.4 + (i*50), height: size.width * 0.3 + (i*40)), 
           tealPaint);
    }

    // 5. Bottom-right textured sphere
    final centerBottomRight = Offset(size.width * 0.9, size.height * 0.85);
    // The sphere base (beige/gray)
    canvas.drawCircle(centerBottomRight, size.width * 0.4, Paint()..color = const Color(0xFFC5C5B1));
    // The inner brown cut
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.82), size.width * 0.28, Paint()..color = const Color(0xFF6A3B43));
    
    // Draw some blue lines wrapping the sphere
    final sphereLinesPaint = Paint()
      ..color = const Color(0xFF5589A3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(
        Rect.fromCenter(center: centerBottomRight, width: size.width * 0.7, height: size.width * 0.7),
        3.14 * 0.65, 3.14 * 0.6, false, sphereLinesPaint);
    canvas.drawArc(
        Rect.fromCenter(center: centerBottomRight, width: size.width * 0.6, height: size.width * 0.6),
        3.14 * 0.7, 3.14 * 0.5, false, sphereLinesPaint);
    canvas.drawArc(
        Rect.fromCenter(center: centerBottomRight, width: size.width * 0.5, height: size.width * 0.5),
        3.14 * 0.75, 3.14 * 0.4, false, sphereLinesPaint);

    // Purple dots scattered around bottom-right
    final dotPaint = Paint()
      ..color = const Color(0xFF9B40C9)
      ..style = PaintingStyle.fill;
    
    final randomPos = [
      Offset(size.width * 0.55, size.height * 0.6),
      Offset(size.width * 0.65, size.height * 0.62),
      Offset(size.width * 0.45, size.height * 0.65),
      Offset(size.width * 0.5, size.height * 0.75),
      Offset(size.width * 0.4, size.height * 0.8),
      Offset(size.width * 0.55, size.height * 0.85),
      Offset(size.width * 0.6, size.height * 0.95),
      Offset(size.width * 0.7, size.height * 0.55),
      Offset(size.width * 0.8, size.height * 0.52),
    ];
    for (var pos in randomPos) {
       canvas.drawCircle(pos, 4, dotPaint);
       canvas.drawCircle(Offset(pos.dx + 15, pos.dy + 20), 3, dotPaint);
       canvas.drawCircle(Offset(pos.dx - 10, pos.dy + 8), 2, dotPaint);
       canvas.drawCircle(Offset(pos.dx + 5, pos.dy - 12), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}"""

split_string = '  @override\n  Widget build(BuildContext context) {'
if split_string in content:
    top_part = content.split(split_string)[0]
    final_content = top_part + new_code
    open('lib/screens/quiz_screen.dart', 'w', encoding='utf-8').write(final_content)
    print('Replaced successfully')
else:
    print('Could not find split string')
