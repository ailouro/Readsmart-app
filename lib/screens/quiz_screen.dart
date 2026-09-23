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
  int _streak = 0;

  // Multiple-choice selection state for the current question.
  int? _selectedIndex;
  bool _answered = false;

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

  /// Options for the current question, with the index of the correct one.
  /// `correct_answer` is matched by text against `options` so the backend
  /// doesn't need to send a separate index field.
  (List<String> options, int correctIndex) _optionsFor(
    Map<String, dynamic> question,
  ) {
    final List<String> options = ((question['options'] as List?) ?? [])
        .map((o) => o.toString())
        .toList();
    final String correctAnswer = (question['correct_answer'] ?? '').toString();
    int correctIndex = options.indexWhere(
      (o) => o.trim() == correctAnswer.trim(),
    );
    if (correctIndex == -1) correctIndex = 0;
    return (options, correctIndex);
  }

  void _selectOption(int tappedIndex, int correctIndex) {
    if (_answered) return;

    final bool isCorrect = tappedIndex == correctIndex;
    setState(() {
      _answered = true;
      _selectedIndex = tappedIndex;
      if (isCorrect) {
        _correctCount++;
        _streak++;
      } else {
        _streak = 0;
      }
    });

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedIndex = null;
          _answered = false;
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
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF6A3B43),
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Score: $correctCount / $total",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (wordsToPractice.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Words to practice: ${wordsToPractice.join(', ')}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (saveFailed) ...[
                const SizedBox(height: 10),
                const Text(
                  "⚠️ We couldn't save your results. Please tell your teacher.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF940D0D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (showLevel) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
            shadows: [
              Shadow(
                color: Colors.black45,
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
            ],
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
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _questions.isEmpty
                      ? const Center(
                          child: Text(
                            "No quiz available for this story.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
            Text(
              "Saving your progress...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    var question = _questions[_currentQuestionIndex] as Map<String, dynamic>;
    final (options, correctIndex) = _optionsFor(question);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score + streak badges
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatBadge(
                    icon: "🔥",
                    value: "$_streak",
                    key: ValueKey("streak_$_streak"),
                  ),
                  const SizedBox(width: 10),
                  _StatBadge(
                    icon: "⭐",
                    value: "$_correctCount",
                    key: ValueKey("score_$_correctCount"),
                  ),
                ],
              ),
            ),

            // Progress indicator
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (idx) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: idx == _currentQuestionIndex ? 24 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: idx < _currentQuestionIndex
                          ? const Color(0xFF679B9B)
                          : idx == _currentQuestionIndex
                          ? const Color(0xFF9B40C9)
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black87, width: 1.5),
                    ),
                  );
                }),
              ),
            ),

            // Question card
            Container(
                  key: ValueKey("q_$_currentQuestionIndex"),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(5, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Question ${_currentQuestionIndex + 1}",
                        style: const TextStyle(
                          color: Color(0xFF9B40C9),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (question['question_text'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C246E),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                )
                .animate(key: ValueKey("wrap_$_currentQuestionIndex"))
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 16),

            // Answer options
            ...List.generate(options.length, (i) {
              final bool isSelected = _selectedIndex == i;
              final bool isCorrectOption = i == correctIndex;
              final bool showCorrect = _answered && isCorrectOption;
              final bool showWrong =
                  _answered && isSelected && !isCorrectOption;

              Color bg = Colors.white;
              if (showCorrect) {
                bg = const Color(0xFF8BCA84);
              } else if (showWrong) {
                bg = const Color(0xFFFC9272);
              }

              Widget optionWidget = Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _answered
                        ? null
                        : () => _selectOption(i, correctIndex),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (showCorrect || showWrong)
                                  ? Colors.white
                                  : const Color(0xFFFDE047),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF2C246E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              options[i],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2C246E),
                              ),
                            ),
                          ),
                          if (showCorrect)
                            const Icon(Icons.check_circle, color: Colors.black),
                          if (showWrong)
                            const Icon(Icons.cancel, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              if (showWrong) {
                optionWidget = optionWidget.animate().shake(
                  duration: 350.ms,
                  hz: 4,
                );
              } else if (showCorrect) {
                optionWidget = optionWidget
                    .animate()
                    .scale(
                      duration: 250.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.03, 1.03),
                    )
                    .then()
                    .scale(
                      duration: 150.ms,
                      begin: const Offset(1.03, 1.03),
                      end: const Offset(1, 1),
                    );
              }
              return optionWidget;
            }),

            const SizedBox(height: 4),

            // Feedback toast
            if (_answered)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _selectedIndex == correctIndex
                      ? (_streak >= 3 ? "🔥 On fire! Great job!" : "✅ Correct!")
                      : "Not quite — the correct answer is highlighted!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(1, 1)),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pill badge used for the streak (🔥) and score (⭐) counters. It
/// pops briefly whenever its value changes, since a new [key] is passed in
/// each time the count updates.
class _StatBadge extends StatelessWidget {
  final String icon;
  final String value;

  const _StatBadge({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF2C246E),
            ),
          ),
        ],
      ),
    ).animate().scale(
      duration: 220.ms,
      begin: const Offset(0.7, 0.7),
      end: const Offset(1, 1),
      curve: Curves.easeOutBack,
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
