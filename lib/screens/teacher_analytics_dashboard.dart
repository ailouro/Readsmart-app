import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/guide_comic_background.dart';

class TeacherAnalyticsDashboard extends StatefulWidget {
  final int teacherId;
  final String baseUrl;

  const TeacherAnalyticsDashboard({
    super.key,
    required this.teacherId,
    required this.baseUrl,
  });

  @override
  State<TeacherAnalyticsDashboard> createState() =>
      _TeacherAnalyticsDashboardState();
}

class _TeacherAnalyticsDashboardState extends State<TeacherAnalyticsDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _summaryData = {};
  List<dynamic> _mispronunciations = [];
  // Words the student got wrong once but corrected themselves on a retry.
  // Kept in its own list (not merged into _mispronunciations) so the
  // dashboard can render it as a distinct, non-alarming column.
  List<dynamic> _selfCorrections = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 🛠️ ROBUST ID FETCHING
      int tId = widget.teacherId;
      if (tId <= 0) {
        final prefs = await SharedPreferences.getInstance();
        tId =
            prefs.getInt('user_id') ??
            prefs.getInt('id') ??
            prefs.getInt('teacher_id') ??
            1;
      }

      // 1. Fetch Class Summary Stats
      final summaryRes = await http.get(
        Uri.parse("${widget.baseUrl}/api/teachers/$tId/dashboard-summary"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      // 2. Fetch Mispronunciation Logs
      final mispronunciationRes = await http.get(
        Uri.parse("${widget.baseUrl}/api/teachers/$tId/mispronunciations"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      // 3. Fetch Self-Corrected Word Logs (words the student got right after
      // a retry — never hurt the score, just useful signal for the teacher)
      final selfCorrectionRes = await http.get(
        Uri.parse("${widget.baseUrl}/api/teachers/$tId/self-corrections"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      if (summaryRes.statusCode == 200 &&
          mispronunciationRes.statusCode == 200 &&
          mounted) {
        final decodedSummary = jsonDecode(summaryRes.body);
        final decodedMispro = jsonDecode(mispronunciationRes.body);

        List<dynamic> decodedSelfCorrections = [];
        if (selfCorrectionRes.statusCode == 200) {
          final decodedSelf = jsonDecode(selfCorrectionRes.body);
          decodedSelfCorrections =
              decodedSelf['data'] ?? decodedSelf['self_corrections'] ?? [];
        }

        setState(() {
          // 🛠️ PROPER JSON PARSING (Salo ang 'data' wrap kung meron)
          _summaryData = decodedSummary['data'] ?? decodedSummary;
          _mispronunciations =
              decodedMispro['data'] ?? decodedMispro['mispronunciations'] ?? [];
          _selfCorrections = decodedSelfCorrections;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading teacher analytics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Analytics"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          ),
        ],
      ),
      body: GuideComicBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Phil-IRI Level Overview",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Phil-IRI Summary Cards
                      Row(
                        children: [
                          _buildStatCard(
                            title: "Frustration",
                            count:
                                _summaryData['frustration_count']?.toString() ??
                                "0",
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            title: "Instructional",
                            count:
                                _summaryData['instructional_count']
                                    ?.toString() ??
                                "0",
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            title: "Independent",
                            count:
                                _summaryData['independent_count']?.toString() ??
                                "0",
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        "Learner's Individual Record Card",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.brown,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Learner Cards
                      if (_summaryData['students'] == null ||
                          (_summaryData['students'] as List).isEmpty)
                        const Text(
                          "No students enrolled yet.",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (_summaryData['students'] as List).length,
                          itemBuilder: (context, index) {
                            final student = Map<String, dynamic>.from(
                              _summaryData['students'][index] as Map,
                            );
                            return _buildLearnerRecordCard(student);
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLearnerRecordCard(Map<String, dynamic> student) {
    List progressLogs = student['progress'] ?? [];

    List studentMispronunciations = _mispronunciations
        .where((m) => m['student_id'].toString() == student['id'].toString())
        .toList();

    List studentSelfCorrections = _selfCorrections
        .where((m) => m['student_id'].toString() == student['id'].toString())
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 135, 41, 34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Table(
            border: TableBorder.all(color: Colors.brown, width: 2),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.brown.shade700),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Name",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Grade & Sec",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "LRN",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                decoration: BoxDecoration(color: Colors.amber.shade200),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      student['name'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${student['grade_level'] ?? ''} ${student['section'] ?? ''}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      student['lrn'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (progressLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.amber.shade200,
              child: const Text(
                "No reading records yet.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            Table(
              border: TableBorder.all(color: Colors.brown, width: 2),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2), // In-adjust ng onti for tooltip space
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.2), // In-adjust ng onti for tooltip space
                4: FlexColumnWidth(2),
                5: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.brown.shade700),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Story",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Level",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Quiz",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "WPM",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Struggled Words",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Self-Corrected",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                ...progressLogs.map((log) {
                  List storyWords = studentMispronunciations
                      .where(
                        (m) =>
                            m['story_id'].toString() ==
                            log['story_id'].toString(),
                      )
                      .toList();
                  String wordsText = storyWords.isEmpty
                      ? "None"
                      : storyWords
                            .map(
                              (w) => "${w['word']} (${w['total_attempts']}x)",
                            )
                            .join(", ");

                  List storySelfCorrections = studentSelfCorrections
                      .where(
                        (m) =>
                            m['story_id'].toString() ==
                            log['story_id'].toString(),
                      )
                      .toList();
                  String selfCorrectedText = storySelfCorrections.isEmpty
                      ? "None"
                      : storySelfCorrections
                            .map(
                              (w) => "${w['word']} (${w['total_attempts']}x)",
                            )
                            .join(", ");

                  // TOOLTIP LOGIC VARIABLES
                  String wpmValue = log['wpm'] != null
                      ? "${(log['wpm'] as num).round()}"
                      : 'N/A';
                  String accuracyValue = log['oral_fluency_accuracy'] != null
                      ? "${log['oral_fluency_accuracy']}%"
                      : 'N/A';
                  String totalWords = log['total_words']?.toString() ?? '?';
                  String correctWords = log['correct_words']?.toString() ?? '?';

                  // Compute minutes and seconds for display
                  String timeSpentDisplay = '? mins';
                  if (log['time_on_task'] != null) {
                    int seconds =
                        int.tryParse(log['time_on_task'].toString()) ?? 0;
                    int mins = seconds ~/ 60;
                    int secs = seconds % 60;
                    timeSpentDisplay = "${mins}m ${secs}s";
                  }

                  return TableRow(
                    decoration: BoxDecoration(color: Colors.amber.shade100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          log['story']?['title'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // LEVEL & ACCURACY WITH TOOLTIP
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                "${log['reading_level'] ?? 'N/A'}\n($accuracyValue)",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Tooltip(
                              message:
                                  "Accuracy Breakdown:\nCorrect: $correctWords words\nTotal: $totalWords words",
                              triggerMode: TooltipTriggerMode.tap,
                              padding: const EdgeInsets.all(12),
                              showDuration: const Duration(seconds: 4),
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "${log['quiz_score'] ?? 0}/${log['total_questions'] ?? 0}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // WPM WITH TOOLTIP
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              wpmValue,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  "Speed Breakdown:\nTime spent: $timeSpentDisplay\nTotal words: $totalWords",
                              triggerMode: TooltipTriggerMode.tap,
                              padding: const EdgeInsets.all(12),
                              showDuration: const Duration(seconds: 4),
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          wordsText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          selfCorrectedText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
