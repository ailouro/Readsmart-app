import sys
import re

content = open('lib/screens/quiz_screen.dart', encoding='utf-8').read()

new_state_code = """class _QuizScreenState extends State<QuizScreen> {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: const Text(
          "🎉 Mission Accomplished!",
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6A3B43)),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Score: $correctCount / ${_questions.length}",
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCA9F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text(
                "Level: ${level.toUpperCase()}",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
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
            child: const Text("Awesome!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}
"""

start_marker = 'class _QuizScreenState extends State<QuizScreen> {'
end_marker = 'class QuizBackgroundPainter extends CustomPainter {'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + new_state_code + content[end_idx:]
    open('lib/screens/quiz_screen.dart', 'w', encoding='utf-8').write(new_content)
    print("Successfully replaced _QuizScreenState in quiz_screen.dart")
else:
    print("Could not find markers!")
