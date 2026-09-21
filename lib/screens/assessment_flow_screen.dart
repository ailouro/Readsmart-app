// lib/screens/assessment_flow_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/assessment_score.dart';
import 'story_view_screen.dart';

class _AssessmentAttempt {
  final int gradeLevel;
  final PassageScore score;
  _AssessmentAttempt({required this.gradeLevel, required this.score});
}

/// Drives the Phil-IRI Stage 2 branching search for one student:
/// serve a passage at the current grade level, score it, move up or
/// down per the classification, and repeat until both an
/// instructional and a frustration boundary are found (or the grade
/// range floor/ceiling is hit).
///
/// This screen owns the loop; StoryViewerScreen and QuizScreen stay
/// exactly as they are (single-passage components run in
/// assessmentMode: true).
class AssessmentFlowScreen extends StatefulWidget {
  final int studentId;
  final String baseUrl;

  /// Grade level to start at. Compute this with
  /// GstPlacement.startingGradeLevel(...) from the student's GST score
  /// before pushing this screen; pass the student's current grade if
  /// you are skipping the GST step.
  final int startingGradeLevel;

  /// Floor and ceiling for the passage library. Scoped to Grades 2-6
  /// by default per the Grade 5-6 deployment cohort (a Grade 5/6
  /// student can be sent up to 3 levels down, per Table 3).
  final int minGradeLevel;
  final int maxGradeLevel;

  final String testType; // "pre_test" | "post_test"

  const AssessmentFlowScreen({
    super.key,
    required this.studentId,
    required this.baseUrl,
    required this.startingGradeLevel,
    this.minGradeLevel = 2,
    this.maxGradeLevel = 6,
    this.testType = "pre_test",
  });

  @override
  State<AssessmentFlowScreen> createState() => _AssessmentFlowScreenState();
}

class _AssessmentFlowScreenState extends State<AssessmentFlowScreen> {
  final List<_AssessmentAttempt> _attempts = [];
  int? _independentLevel;
  int? _instructionalLevel;
  int? _frustrationLevel;

  bool _isLoadingPassage = true;
  bool _isComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runNextPassage(widget.startingGradeLevel);
  }

  /// Fetches one assessment-tagged passage at [gradeLevel].
  ///
  /// ASSUMPTION TO VERIFY: this assumes a Laravel route like
  /// GET /api/stories?grade=X&type=assessment&test_type=pre_test
  /// returning {"stories": [...]}. Adjust the endpoint/query params
  /// and response parsing to match your actual API — this is the one
  /// piece that has to match your backend exactly.
  Future<Map<String, dynamic>?> _fetchPassageForGrade(int gradeLevel) async {
    try {
      final uri = Uri.parse(
        "${widget.baseUrl}/api/stories"
        "?grade=$gradeLevel&type=assessment&test_type=${widget.testType}",
      );
      final response = await http.get(
        uri,
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final List<dynamic> stories = data['stories'] ?? data['data'] ?? [];
      if (stories.isEmpty) return null;

      // TODO: once you have parallel sets (A-D), exclude passages
      // already used this session (track _attempts) so a student never
      // repeats a passage within one assessment run. For now this
      // takes whatever the backend returns first.
      return Map<String, dynamic>.from(stories.first);
    } catch (e) {
      debugPrint("Error fetching passage for grade $gradeLevel: $e");
      return null;
    }
  }

  Future<void> _runNextPassage(int gradeLevel) async {
    final bool hitFloor = gradeLevel < widget.minGradeLevel;
    final bool hitCeiling = gradeLevel > widget.maxGradeLevel;
    final int clampedGrade = gradeLevel.clamp(
      widget.minGradeLevel,
      widget.maxGradeLevel,
    );

    setState(() {
      _isLoadingPassage = true;
      _errorMessage = null;
    });

    final passage = await _fetchPassageForGrade(clampedGrade);
    if (!mounted) return;

    if (passage == null) {
      setState(() {
        _isLoadingPassage = false;
        _errorMessage =
            "No assessment passage available for Grade $clampedGrade.";
      });
      return;
    }

    setState(() => _isLoadingPassage = false);

    final score = await Navigator.push<PassageScore>(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          story: passage,
          baseUrl: widget.baseUrl,
          studentId: widget.studentId,
          testType: widget.testType,
          assessmentMode: true,
        ),
      ),
    );

    if (!mounted || score == null) return;

    _attempts.add(_AssessmentAttempt(gradeLevel: clampedGrade, score: score));
    _recordBoundary(clampedGrade, score);

    if (_bothBoundariesFound() || hitFloor || hitCeiling) {
      await _finishAssessment();
      return;
    }

    final nextGrade = clampedGrade + score.nextGradeLevelOffset;
    _runNextPassage(nextGrade);
  }

  void _recordBoundary(int gradeLevel, PassageScore score) {
    switch (score.overallLevel) {
      case ReadingLevel.independent:
        // Highest grade level at which the student still reads
        // independently.
        if (_independentLevel == null || gradeLevel > _independentLevel!) {
          _independentLevel = gradeLevel;
        }
        break;
      case ReadingLevel.instructional:
        _instructionalLevel = gradeLevel;
        break;
      case ReadingLevel.frustration:
        // Lowest grade level at which the student is still frustrated
        // (the downward search stops once this is confirmed).
        if (_frustrationLevel == null || gradeLevel < _frustrationLevel!) {
          _frustrationLevel = gradeLevel;
        }
        break;
    }
  }

  bool _bothBoundariesFound() {
    return _instructionalLevel != null && _frustrationLevel != null;
  }

  /// ASSUMPTION TO VERIFY: POSTs the final result to
  /// /api/student/reading-levels. Adjust to your actual endpoint —
  /// this mirrors the shape of the /api/student/progress calls already
  /// used in story_view_screen.dart and quiz_screen.dart.
  Future<void> _finishAssessment() async {
    setState(() => _isComplete = true);

    try {
      await http.post(
        Uri.parse("${widget.baseUrl}/api/student/reading-levels"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "student_id": widget.studentId,
          "test_type": widget.testType,
          "independent_level": _independentLevel,
          "instructional_level": _instructionalLevel,
          "frustration_level": _frustrationLevel,
          "attempts": _attempts
              .map(
                (a) => {
                  "grade_level": a.gradeLevel,
                  "word_reading_pct": a.score.wrPct,
                  "comprehension_pct": a.score.compPct,
                  "classification": a.score.levelLabel,
                },
              )
              .toList(),
        }),
      );
    } catch (e) {
      debugPrint("Error saving reading levels: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isComplete) return _buildResultsScreen();

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Reading Assessment")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _finishAssessment,
                  child: const Text("Finish with results so far"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Reading Assessment")),
      body: Center(
        child: _isLoadingPassage
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Preparing the next passage..."),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text("Reading Levels")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _levelTile("Independent", _independentLevel),
            _levelTile("Instructional", _instructionalLevel),
            _levelTile("Frustration", _frustrationLevel),
            const SizedBox(height: 24),
            const Text(
              "Attempt history",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _attempts.length,
                itemBuilder: (context, i) {
                  final a = _attempts[i];
                  return ListTile(
                    title: Text(
                      "Grade ${a.gradeLevel} — ${a.score.levelLabel}",
                    ),
                    subtitle: Text(
                      "WR: ${a.score.wrPct.toStringAsFixed(1)}%  •  "
                      "Comp: ${a.score.compPct.toStringAsFixed(1)}%",
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelTile(String label, int? gradeLevel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$label: ${gradeLevel != null ? 'Grade $gradeLevel' : 'Not determined'}",
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
