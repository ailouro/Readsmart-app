import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/assessment_score.dart';
import '../services/phil_iri_rules.dart';
import '../services/phil_iri_session.dart';
import 'story_view_screen.dart';

enum _Phase { loading, ready, fetching, notNeeded, error, complete }

class AssessmentFlowScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  final int studentGrade;

  /// 'pre_test' or 'post_test'.
  final String testType;

  /// 'A' to 'D'.
  final String setLetter;

  /// English GST raw score (0-20).
  final int? gstRaw;

  final int? directStartGrade;

  const AssessmentFlowScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
    required this.studentGrade,
    required this.testType,
    required this.setLetter,
    this.gstRaw,
    this.directStartGrade,
  });

  @override
  State<AssessmentFlowScreen> createState() => _AssessmentFlowScreenState();
}

class _AssessmentFlowScreenState extends State<AssessmentFlowScreen> {
  static const Color _maroon = Color(0xFF9B0505);
  static const Color _yellow = Color(0xFFFDE047);
  static const Color _background = Color(0xFFFAF6F6);

  PhilIriSession? _session;
  _Phase _phase = _Phase.loading;
  String _error = '';
  bool _saveWarning = false;

  String get _prefsKey =>
      'stage2_${widget.studentId}_${widget.testType}_${widget.setLetter}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _phase = _Phase.loading);
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      try {
        _session = PhilIriSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      } catch (_) {
        _session = null;
      }
    }

    // Limit student grade strictly to Grade 5 or Grade 6
    final int clampedStudentGrade = widget.studentGrade.clamp(5, 6);

    if (_session == null) {
      if (widget.testType == 'pre_test') {
        final gst = widget.gstRaw;
        if (gst != null) {
          _session = PhilIriSession.forPreTest(
            studentId: widget.studentId,
            studentGrade: clampedStudentGrade,
            gstRaw: gst,
            setLetter: widget.setLetter,
          );
          if (_session == null) {
            if (mounted) setState(() => _phase = _Phase.notNeeded);
            return;
          }
        } else {
          final direct = widget.directStartGrade ?? clampedStudentGrade;
          final clampedDirect = direct.clamp(5, 6);
          _session = PhilIriSession.forPreTestAtGrade(
            studentId: widget.studentId,
            studentGrade: clampedStudentGrade,
            setLetter: widget.setLetter,
            startGrade: clampedDirect,
          );
        }
      } else {
        // POST TEST: Ensure starting grade is strictly Grade 5 or 6
        final start = widget.directStartGrade ?? clampedStudentGrade;
        final clampedStart = start.clamp(5, 6);

        _session = PhilIriSession.forPostTest(
          studentId: widget.studentId,
          studentGrade: clampedStudentGrade,
          setLetter: widget.setLetter,
          startGrade: clampedStart,
        );
      }
      await _saveSession();
    }

    if (!mounted) return;
    setState(() {
      _phase = _session!.isComplete ? _Phase.complete : _Phase.ready;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _phase = _Phase.error;
    });
  }

  Future<void> _saveSession() async {
    final session = _session;
    if (session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(session.toJson()));
  }

  Future<dynamic> _fetchPassage(int grade) async {
    // Safety check for Grade 5 and 6 limit
    if (grade < 5 || grade > 6) {
      _error =
          'Only Grade 5 and Grade 6 stories are available for this assessment.';
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/assessment-passage'
          '?test_type=${widget.testType}'
          '&set_letter=${widget.setLetter}'
          '&grade=$grade',
        ),
        headers: const {'ngrok-skip-browser-warning': '69420'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final story = data['story'];
        final pages = story == null ? null : story['pages'];
        if (pages is List && pages.isNotEmpty) return story;
      }
      _error =
          'We could not find the Grade $grade story for Set ${widget.setLetter}. '
          'Please tell your teacher.';
    } catch (e) {
      debugPrint('Assessment passage error: $e');
      _error = 'No connection. Check your internet and try again.';
    }
    return null;
  }

  Future<void> _readNextPassage() async {
    final session = _session;
    if (session == null) {
      await _init();
      return;
    }
    final rawGrade = session.nextGrade;
    if (rawGrade == null) {
      await _finish();
      return;
    }

    // Limit scope: If Phil-IRI attempts to test outside Grade 5-6, finish assessment cleanly.
    if (rawGrade < 5 || rawGrade > 6) {
      await _finish();
      return;
    }

    final grade = rawGrade;

    setState(() => _phase = _Phase.fetching);
    final story = await _fetchPassage(grade);
    if (!mounted) return;
    if (story == null) {
      setState(() => _phase = _Phase.error);
      return;
    }

    final score = await Navigator.push<PassageScore>(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          story: story,
          baseUrl: widget.baseUrl,
          studentId: widget.studentId,
          testType: widget.testType,
          assessmentMode: true,
        ),
      ),
    );
    if (!mounted) return;

    if (score == null) {
      setState(() => _phase = _Phase.ready);
      return;
    }

    final result = PassageResult.score(
      grade: grade,
      storyId: story['id'] ?? story['_id'],
      wrPct: score.wrPct,
      compCorrect: score.compCorrect,
      compTotal: score.compTotal,
      rule: score.compTotal == 0 ? LevelRule.wordReadingOnly : session.rule,
    );
    session.record(result);
    await _saveSession();
    await _postPassage(story, result, score);

    if (!mounted) return;
    if (session.nextGrade == null ||
        session.nextGrade! < 5 ||
        session.nextGrade! > 6) {
      await _finish();
    } else {
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _postPassage(
    dynamic story,
    PassageResult result,
    PassageScore score,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/student/progress'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420',
        },
        body: jsonEncode({
          'student_id': widget.studentId,
          'user_id': widget.studentId,
          'story_id': story['id'] ?? story['_id'],
          'quiz_score': score.compCorrect,
          'total_questions': score.compTotal,
          'oral_fluency_accuracy': score.wrPct,
          'total_words': score.totalWords,
          'correct_words': score.correctWords,
          'time_on_task': score.readingSeconds > 0 ? score.readingSeconds : 1,
          'wpm': double.parse(score.wordsPerMinute.toStringAsFixed(2)),
          'struggled_words': score.struggledWords.join(', '),
          'test_type': widget.testType,
          'set_letter': widget.setLetter,
          'assessment_grade': result.grade,
          'wr_level': result.wrLevel.name,
          'comp_level': result.compLevel.name,
          'passage_level': result.level.name,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        _saveWarning = true;
      }
    } catch (e) {
      debugPrint('Assessment progress save error: $e');
      _saveWarning = true;
    }
  }

  Future<void> _finish() async {
    final session = _session!;
    final outcome = session.outcome;
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/student/assessment-outcome'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420',
        },
        body: jsonEncode({
          'student_id': widget.studentId,
          'test_type': widget.testType,
          'set_letter': widget.setLetter,
          'start_grade': session.startGrade.clamp(5, 6),
          'independent_grade': outcome.independentGrade,
          'instructional_grade': outcome.instructionalGrade,
          'frustration_grade': outcome.frustrationGrade,
          'below_range': outcome.belowRange,
          'above_range': outcome.aboveRange,
          'session': session.toJson(),
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        _saveWarning = true;
      }
    } catch (e) {
      debugPrint('Assessment outcome save error: $e');
      _saveWarning = true;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.complete);
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _yellow,
          foregroundColor: Colors.black,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 2.5),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _title(String emoji, String text) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6A3B43),
          ),
        ),
      ],
    );
  }

  Widget _body(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.loading:
      case _Phase.fetching:
        return _card(
          children: [
            const CircularProgressIndicator(color: _maroon),
            const SizedBox(height: 16),
            Text(
              _phase == _Phase.fetching
                  ? 'Getting your story ready...'
                  : 'Loading...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );

      case _Phase.ready:
        final number = (_session?.history.length ?? 0) + 1;
        final first = number == 1;
        return _card(
          children: [
            _title(
              first ? '📚' : '👏',
              first
                  ? "Let's start your reading test!"
                  : 'Nice work! Ready for the next story?',
            ),
            _body(
              'Story $number\n\n'
              'Read the words out loud. Then answer the questions about the story.',
            ),
            _button(first ? 'Start' : 'Next Story', _readNextPassage),
          ],
        );

      case _Phase.notNeeded:
        return _card(
          children: [
            _title('🌟', "You don't need this test right now"),
            _body(
              'Your screening score shows you are doing well. Keep reading!',
            ),
            _button('Back', () => Navigator.pop(context, false)),
          ],
        );

      case _Phase.error:
        return _card(
          children: [
            _title('😕', 'Oops!'),
            _body(_error),
            _button('Try Again', _readNextPassage),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
          ],
        );

      case _Phase.complete:
        return _card(
          children: [
            _title('🎉', 'All done!'),
            _body(
              'You finished your reading test. '
              'Your teacher will go over your results with you.',
            ),
            if (_saveWarning)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  "⚠️ We couldn't save everything. Please tell your teacher.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF940D0D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            _button('Finish', () => Navigator.pop(context, true)),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Reading Test',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _content(),
          ),
        ),
      ),
    );
  }
}
