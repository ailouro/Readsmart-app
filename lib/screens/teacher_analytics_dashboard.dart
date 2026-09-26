import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
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
  List<dynamic> _selfCorrections = [];

  // 🔊 Audio player state for playing struggle word recordings
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlayingAudio = false;

  final Map<dynamic, Future<List<dynamic>>> _progressCache = {};

  Future<List<dynamic>> _fetchStudentProgress(dynamic studentId) {
    return _progressCache.putIfAbsent(studentId, () async {
      try {
        final res = await http.get(
          Uri.parse("${widget.baseUrl}/api/student/$studentId/all-progress"),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        );
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['data'] is List) {
            return decoded['data'] as List<dynamic>;
          }
          if (decoded is List) return decoded;
        }
      } catch (e) {
        debugPrint("Error fetching progress for student $studentId: $e");
      }
      return <dynamic>[];
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
  }

  Future<void> _togglePlayStruggleAudio(String audioUrl) async {
    try {
      if (_currentlyPlayingUrl == audioUrl && _isPlayingAudio) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _currentlyPlayingUrl = null;
          });
        }
        return;
      }

      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentlyPlayingUrl = audioUrl;
          _isPlayingAudio = true;
        });
      }
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint("Audio playback error: $e");
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingUrl = null;
        });
      }
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      int tId = widget.teacherId;
      if (tId <= 0) {
        final prefs = await SharedPreferences.getInstance();
        tId =
            prefs.getInt('user_id') ??
            prefs.getInt('id') ??
            prefs.getInt('teacher_id') ??
            1;
      }

      final summaryRes = await http.get(
        Uri.parse("${widget.baseUrl}/api/teachers/$tId/dashboard-summary"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      final mispronunciationRes = await http.get(
        Uri.parse("${widget.baseUrl}/api/teachers/$tId/mispronunciations"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

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
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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

                      const SizedBox(height: 20),
                      _buildClassLevelChart(),
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
    return FutureBuilder<List<dynamic>>(
      future: _fetchStudentProgress(student['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildLearnerRecordCardContent(
          student,
          snapshot.data ?? const [],
        );
      },
    );
  }

  Widget _buildLearnerRecordCardContent(
    Map<String, dynamic> student,
    List progressLogs,
  ) {
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
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.0),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(
                  2.5,
                ), // Expanded space for playable Audio Chips
                5: FlexColumnWidth(1.8),
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
                        "Struggled Words & Audio",
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

                  String wpmValue = log['wpm'] != null
                      ? "${(log['wpm'] as num).round()}"
                      : 'N/A';
                  String accuracyValue = log['oral_fluency_accuracy'] != null
                      ? "${log['oral_fluency_accuracy']}%"
                      : 'N/A';
                  String totalWords = log['total_words']?.toString() ?? '?';
                  String correctWords = log['correct_words']?.toString() ?? '?';

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

                      // 🔊 PLAYABLE STRUGGLED WORDS CHIPS WITH AUDIO RECORDING & MISCUE BADGES
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: storyWords.isEmpty
                            ? const Text(
                                "None",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              )
                            : Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: storyWords.map((item) {
                                  final String wordText = item['word'] ?? '';
                                  final String? audioUrl = item['audio_url'];
                                  final String miscueType =
                                      item['miscue_type'] ?? 'mispronunciation';
                                  final int attempts =
                                      item['total_attempts'] ?? 3;

                                  final bool isThisPlaying =
                                      _isPlayingAudio &&
                                      _currentlyPlayingUrl == audioUrl;

                                  Color chipBg = miscueType == 'omission'
                                      ? Colors.grey.shade800
                                      : Colors.red.shade900;

                                  return InkWell(
                                    onTap:
                                        audioUrl != null && audioUrl.isNotEmpty
                                        ? () =>
                                              _togglePlayStruggleAudio(audioUrl)
                                        : null,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: chipBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isThisPlaying
                                              ? Colors.amberAccent
                                              : Colors.black,
                                          width: isThisPlaying ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            miscueType == 'omission'
                                                ? "$wordText (omitted)"
                                                : "$wordText (${attempts}x)",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (audioUrl != null &&
                                              audioUrl.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              isThisPlaying
                                                  ? Icons.stop_circle
                                                  : Icons.volume_up,
                                              color: isThisPlaying
                                                  ? Colors.amberAccent
                                                  : Colors.white,
                                              size: 13,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
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

  // Distinct color per class/section bar in the chart below. Cycles if
  // there are more classes than colors.
  static const List<Color> _classChartPalette = [
    Color(0xFF7CB342), // green
    Color(0xFFEC80CB), // pink
    Color(0xFF9FA8DA), // lavender
    Color(0xFFFFC107), // amber
    Color(0xFF4FC3F7), // sky blue
    Color(0xFFFF8A65), // coral
    Color(0xFFBA68C8), // purple
    Color(0xFF4DB6AC), // teal
  ];

  static String _safeStr(dynamic value, [String fallback = ""]) {
    if (value == null) return fallback;
    final str = value.toString();
    if (str.isEmpty || str == "null") return fallback;
    return str;
  }

  /// "Reading Level by Class & Section" chart: one group per Phil-IRI level
  /// (Frustration / Instructional / Independent), one colored bar per class
  /// inside each group. Hovering (web/desktop) or tapping (mobile) a bar
  /// shows which class/section it belongs to and the count, e.g.
  /// "Grade 5 - Magsaysay: 12 students".
  Widget _buildClassLevelChart() {
    final List classBreakdown =
        (_summaryData['class_breakdown'] as List?) ?? [];

    if (classBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    const levelKeys = ['frustration', 'instructional', 'independent'];
    const levelLabels = ['Frustration', 'Instructional', 'Independent'];

    double maxY = 1;
    for (final c in classBreakdown) {
      for (final key in levelKeys) {
        final v = ((c[key] ?? 0) as num).toDouble();
        if (v > maxY) maxY = v;
      }
    }
    maxY = (maxY * 1.25).ceilToDouble();

    final barGroups = List<BarChartGroupData>.generate(levelKeys.length, (
      levelIndex,
    ) {
      final rods = List<BarChartRodData>.generate(classBreakdown.length, (
        classIndex,
      ) {
        final c = classBreakdown[classIndex];
        final value = ((c[levelKeys[levelIndex]] ?? 0) as num).toDouble();
        return BarChartRodData(
          toY: value,
          width: 14,
          color: _classChartPalette[classIndex % _classChartPalette.length],
          borderRadius: BorderRadius.circular(3),
        );
      });
      return BarChartGroupData(x: levelIndex, barRods: rods, barsSpace: 4);
    });

    String labelFor(dynamic c) {
      final label = _safeStr(c['label']);
      if (label.isNotEmpty) return label;
      final grade = _safeStr(c['grade_level'], 'N/A');
      final section = _safeStr(c['section']);
      return section.isEmpty ? "Grade $grade" : "Grade $grade - $section";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Reading Level by Class & Section",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          const Text(
            "Hover or tap a bar to see the class/section and count.",
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: barGroups,
                groupsSpace: 24,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= levelLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            levelLabels[i],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final c = classBreakdown[rodIndex];
                      final levelLabel = levelLabels[group.x.toInt()];
                      final count = rod.toY.toInt();
                      return BarTooltipItem(
                        "${labelFor(c)}\n",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text:
                                "$levelLabel: $count student${count == 1 ? '' : 's'}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(classBreakdown.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _classChartPalette[i % _classChartPalette.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labelFor(classBreakdown[i]),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
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
