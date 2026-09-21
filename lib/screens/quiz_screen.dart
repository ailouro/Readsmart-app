import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../services/assessment_score.dart';

class QuizScreen extends StatefulWidget {
  final int storyId;
  final int studentId;
  final String baseUrl;
  final double oralAccuracy;
  final int totalWords;
  final int readingTimeSeconds;
  final List<String> struggledWords;
  final String testType;

  /// Phil-IRI assessment mode: skip saving and the results dialog, and pop
  /// with a [PassageScore] so the assessment flow can score the passage.
  final bool assessmentMode;

  const QuizScreen({
    super.key,
    required this.storyId,
    required this.studentId,
    this.testType = "post_test",
    required this.baseUrl,
    required this.oralAccuracy,
    this.totalWords = 0,
    this.readingTimeSeconds = 120,
    this.struggledWords = const [],
    this.assessmentMode = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  int _currentQuestionIndex = 0;
  int _correctCount = 0;
  bool _isAnswered = false;
  int? _selectedOptionIndex;

  double get _wordsPerMinute {
    if (widget.readingTimeSeconds <= 0 || widget.totalWords <= 0) return 0;
    return (widget.totalWords / widget.readingTimeSeconds) * 60;
  }

  @override
  void initState() {
    super.initState();
    _fetchQuizQuestions();
  }

  Future<void> _fetchQuizQuestions() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.baseUrl}/api/stories/${widget.storyId}/quiz"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _questions = data['quiz']?['questions'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching quiz: $e");
      setState(() => _isLoading = false);
    }

    // Assessment mode: a passage without a quiz is scored on word reading
    // only, so hand the result back instead of leaving the student stuck.
    if (widget.assessmentMode && mounted && _questions.isEmpty) {
      _finishAssessmentPassage();
    }
  }

  void _finishAssessmentPassage() {
    if (!mounted) return;
    Navigator.pop(
      context,
      PassageScore(
        wrPct: widget.oralAccuracy,
        totalWords: widget.totalWords,
        readingSeconds: widget.readingTimeSeconds,
        struggledWords: widget.struggledWords,
        compCorrect: _correctCount,
        compTotal: _questions.length,
      ),
    );
  }

  void _handleAnswer(int idx, String selectedString, String correctString) {
    if (_isAnswered) return;
    
    setState(() {
      _isAnswered = true;
      _selectedOptionIndex = idx;
      if (selectedString == correctString) _correctCount++;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _isAnswered = false;
          _selectedOptionIndex = null;
        });
      } else {
        _submitQuizData();
      }
    });
  }

  Future<void> _submitQuizData() async {
    if (widget.assessmentMode) {
      _finishAssessmentPassage();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse("${widget.baseUrl}/api/student/progress"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "user_id": widget.studentId,
          "story_id": widget.storyId,
          "quiz_score": _correctCount,
          "total_questions": _questions.length,
          "oral_fluency_accuracy": widget.oralAccuracy,
          "time_on_task": widget.readingTimeSeconds > 0
              ? widget.readingTimeSeconds
              : 120,
          "total_words": widget.totalWords,
          "wpm": double.parse(_wordsPerMinute.toStringAsFixed(2)),
          "struggled_words": widget.struggledWords.join(", "),
          "test_type": widget.testType,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'story_${widget.storyId}_${widget.testType}_quiz_score',
        _correctCount,
      );
      await prefs.setInt(
        'story_${widget.storyId}_${widget.testType}_quiz_total',
        _questions.length,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        String level = resData['progress']?['reading_level'] ?? 'evaluated';
        _showCompletionDialog(_correctCount, level);
      } else {
        _showCompletionDialog(_correctCount, 'evaluated (offline/error)');
      }
    } catch (e) {
      debugPrint("Error submitting quiz: $e");
      _showCompletionDialog(_correctCount, 'evaluated (offline/error)');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCompletionDialog(int correctCount, String level) {
    if (!mounted) return;

    final int total = _questions.length;
    final double ratio = total > 0 ? correctCount / total : 0.0;
    final String levelLower = level.toLowerCase();
    final bool saveFailed =
        levelLower.contains('offline') || levelLower.contains('error');

    // Pick the tone of the feedback (2 = great, 1 = good, 0 = needs practice).
    // Prefer the reading level computed by the server; fall back to the quiz
    // score when the level is unknown. A low quiz score never gets "great".
    int tier;
    if (levelLower.contains('independent')) {
      tier = 2;
    } else if (levelLower.contains('instructional')) {
      tier = 1;
    } else if (levelLower.contains('frustration')) {
      tier = 0;
    } else {
      tier = ratio >= 0.8 ? 2 : (ratio >= 0.5 ? 1 : 0);
    }
    if (ratio < 0.5 && tier > 1) tier = 1;

    final String title = tier == 2
        ? "🎉 Great job!"
        : tier == 1
            ? "👍 Good work!"
            : "💪 Keep practicing!";
    final String message = tier == 2
        ? "You read and answered the questions really well. Keep it up!"
        : tier == 1
            ? "You're getting there! Read the story again and practice the tricky words to get even better."
            : "This one was a little hard, and that's okay. Try reading the story again slowly and practice the words you found tricky. You can do it!";
    final Color levelColor = tier == 2
        ? const Color(0xFF8BCA84)
        : tier == 1
            ? const Color(0xFFFDE047)
            : const Color(0xFFFC9272);
    final List<String> wordsToPractice = widget.struggledWords
        .where((w) => w.trim().isNotEmpty)
        .take(5)
        .toList();
    final bool showLevel = !saveFailed && levelLower != 'evaluated';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6A3B43)),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Score: $correctCount / $total",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Accuracy: ${widget.oralAccuracy.toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Speed: ${_wordsPerMinute.round()} WPM",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (wordsToPractice.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Words to practice: ${wordsToPractice.join(', ')}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ],
              if (saveFailed) ...[
                const SizedBox(height: 10),
                const Text(
                  "⚠️ We couldn't save your results. Please tell your teacher.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF940D0D), fontWeight: FontWeight.bold),
                ),
              ],
              if (showLevel) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    "Level: ${level.toUpperCase()}",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B40C9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              tier == 2 ? "Awesome!" : "Continue",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Story Quiz",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 24,
            shadows: [Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 4)],
          ),
        ),
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
                      ? const Center(
                          child: Text(
                            "No quiz available for this story.",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        )
                      : _buildQuizGame(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuizGame() {
    if (_isSubmitting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text("Saving your progress...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    var question = _questions[_currentQuestionIndex];
    List<dynamic> options = question['options'] ?? [];
    String correctString = question['correct_answer'] ?? "";

    return Center(
      child: SingleChildScrollView(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: const Text(
            "Read each question, then tap the answer you think is correct. "
            "Green means correct and red means not quite.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C246E)),
          ),
        ),

        // Progress indicator
        Container(
          margin: const EdgeInsets.only(bottom: 20, top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_questions.length, (idx) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: idx == _currentQuestionIndex ? 24 : 12,
                height: 12,
                decoration: BoxDecoration(
                  color: idx < _currentQuestionIndex ? const Color(0xFF679B9B) : idx == _currentQuestionIndex ? const Color(0xFF9B40C9) : Colors.white54,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black87, width: 1.5),
                ),
              );
            }),
          ),
        ),
        
        // Question Card
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 3),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  "Question ${_currentQuestionIndex + 1}",
                  style: const TextStyle(color: Color(0xFF9B40C9), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  question['question_text'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2C246E)),
                ),
              ],
            ),
          ),
        ).animate(key: ValueKey(_currentQuestionIndex)).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 30),
        
        // Options
        ...List.generate(options.length, (optIdx) {
          String optString = options[optIdx].toString();
          bool isSelected = _selectedOptionIndex == optIdx;
          bool isCorrectOption = optString == correctString;
          
          Color btnColor = Colors.white;
          Color textColor = const Color(0xFF2C246E);
          
          if (_isAnswered) {
            if (isCorrectOption) {
              btnColor = Colors.greenAccent;
              textColor = Colors.black;
            } else if (isSelected) {
              btnColor = Colors.redAccent;
              textColor = Colors.white;
            } else {
              btnColor = Colors.white54;
            }
          } else if (isSelected) {
            btnColor = const Color(0xFFDCA9F5);
          }

          Widget optBtn = Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
                elevation: isSelected ? 2 : 5,
              ),
              onPressed: _isAnswered ? null : () => _handleAnswer(optIdx, optString, correctString),
              child: Text(
                optString,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          );

          if (_isAnswered && isSelected && !isCorrectOption) {
            optBtn = optBtn.animate().shake(duration: 400.ms);
          } else if (_isAnswered && isCorrectOption) {
            optBtn = optBtn.animate().scale(begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05), duration: 200.ms).then().scale(begin: const Offset(1.05, 1.05), end: const Offset(1.0, 1.0));
          }

          return optBtn.animate(key: ValueKey("${_currentQuestionIndex}_$optIdx"), delay: (100 * optIdx).ms).fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
        }),

        // Feedback right after answering
        if (_isAnswered)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Text(
              (_selectedOptionIndex != null &&
                      options[_selectedOptionIndex!].toString() == correctString)
                  ? "✅ Correct! Well done."
                  : "❌ Not quite. The correct answer is: $correctString",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C246E)),
            ),
          ),
      ],
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
    pathBeige.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.1,
      size.width * 0.9,
      size.height * 0.05,
    );
    pathBeige.quadraticBezierTo(
      size.width,
      size.height * 0.2,
      size.width,
      size.height * 0.25,
    );
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
    pathSquiggle.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.05,
      size.width * 0.85,
      size.height * 0.05,
    );
    pathSquiggle.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.08,
      size.width * 0.92,
      size.height * 0.15,
    );
    canvas.drawPath(pathSquiggle, paintSquiggle);

    final pathSquiggle2 = Path();
    pathSquiggle2.moveTo(size.width * 0.85, 0);
    pathSquiggle2.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.1,
      size.width * 0.98,
      size.height * 0.2,
    );
    canvas.drawPath(pathSquiggle2, paintSquiggle);

    // 3. Top-left dark nested circles
    final centerTopLeft = Offset(size.width * 0.1, size.height * 0.1);
    // Outer dark gray
    canvas.drawCircle(
      centerTopLeft,
      size.width * 0.45,
      Paint()..color = const Color(0xFF4C4C54),
    );
    // Inner navy blue
    canvas.drawCircle(
      centerTopLeft,
      size.width * 0.3,
      Paint()..color = const Color(0xFF2C246E),
    );

    // Spiraling light purple/white lines inside the navy blue circle
    final spiralPaint = Paint()
      ..color = const Color(0xFF8672C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        centerTopLeft,
        size.width * 0.06 * (i + 1),
        spiralPaint,
      );
    }
    // Dots near top-left
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.04),
      8,
      Paint()..color = const Color(0xFF8BA6B9),
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.06),
      11,
      Paint()..color = const Color(0xFF8BA6B9),
    );
    canvas.drawCircle(
      Offset(size.width * 0.33, size.height * 0.09),
      6,
      Paint()..color = const Color(0xFF8BA6B9),
    );

    // 4. Bottom-left concentric ovals (teal)
    final centerBottomLeft = Offset(size.width * 0.15, size.height * 0.9);
    final tealPaint = Paint()
      ..color = const Color(0xFF679B9B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < 6; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: centerBottomLeft,
          width: size.width * 0.4 + (i * 50),
          height: size.width * 0.3 + (i * 40),
        ),
        tealPaint,
      );
    }

    // 5. Bottom-right textured sphere
    final centerBottomRight = Offset(size.width * 0.9, size.height * 0.85);
    // The sphere base (beige/gray)
    canvas.drawCircle(
      centerBottomRight,
      size.width * 0.4,
      Paint()..color = const Color(0xFFC5C5B1),
    );
    // The inner brown cut
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.82),
      size.width * 0.28,
      Paint()..color = const Color(0xFF6A3B43),
    );

    // Draw some blue lines wrapping the sphere
    final sphereLinesPaint = Paint()
      ..color = const Color(0xFF5589A3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(
      Rect.fromCenter(
        center: centerBottomRight,
        width: size.width * 0.7,
        height: size.width * 0.7,
      ),
      3.14 * 0.65,
      3.14 * 0.6,
      false,
      sphereLinesPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: centerBottomRight,
        width: size.width * 0.6,
        height: size.width * 0.6,
      ),
      3.14 * 0.7,
      3.14 * 0.5,
      false,
      sphereLinesPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: centerBottomRight,
        width: size.width * 0.5,
        height: size.width * 0.5,
      ),
      3.14 * 0.75,
      3.14 * 0.4,
      false,
      sphereLinesPaint,
    );

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
}
