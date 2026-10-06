import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'class_report_pdf.dart';
import 'student_progress_screen.dart';
import '../widgets/guide_comic_background.dart';
import '../widgets/phil_iri_analytics_panel.dart';

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
  String _summaryTestType = 'post_test'; // 'pre_test' | 'post_test'
  Map<String, dynamic> _summaryData = {};
  List<dynamic> _mispronunciations = [];
  List<dynamic> _selfCorrections = [];
  bool _isExporting = false; // gumagawa ng class PDF report
  Future<List<List<dynamic>>>? _rosterFuture; // totals ng lahat ng estudyante

  // 🔊 Audio player state for playing struggle word recordings
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlayingAudio = false;

  final Map<dynamic, Future<List<dynamic>>> _progressCache = {};
  final Map<dynamic, Map<String, dynamic>> _totalsByStudent = {};
  final Map<dynamic, Future<List<Map<String, dynamic>>>>
  _assessmentsFutureCache = {};

  Future<List<dynamic>> _fetchStudentProgress(dynamic studentId) {
    return _progressCache.putIfAbsent(studentId, () async {
      try {
        final res = await http.get(
          Uri.parse("${widget.baseUrl}/api/student/$studentId/progress-detail"),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        );
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['totals'] is Map) {
            _totalsByStudent[studentId] = Map<String, dynamic>.from(
              decoded['totals'] as Map,
            );
          }
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

  List<String> _resolveStudentClassIds(Map<String, dynamic> student) {
    final Set<String> ids = {};
    void addFrom(dynamic c) {
      if (c is Map) {
        final id = c['id'] ?? c['_id'] ?? c['class_id'];
        if (id != null) ids.add(id.toString());
      } else if (c is List) {
        for (final item in c) {
          addFrom(item);
        }
      }
    }

    addFrom(student['classes']); // User::classes() — confirmed field
    addFrom(student['school_classes']);
    addFrom(student['school_class']);
    addFrom(student['class']);
    final singleId = student['class_id'] ?? student['classId'];
    if (singleId != null) ids.add(singleId.toString());
    return ids.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchStudentAssessments(
    Map<String, dynamic> student,
  ) {
    final studentId = student['id'] ?? student['user_id'];
    if (studentId == null) return Future.value(const []);
    return _assessmentsFutureCache.putIfAbsent(studentId, () async {
      final classIds = _resolveStudentClassIds(student);
      final List<Map<String, dynamic>> merged = [];
      for (final classId in classIds) {
        try {
          final res = await http.get(
            Uri.parse(
              "${widget.baseUrl}/api/classes/$classId/assessments?student_id=$studentId",
            ),
            headers: const {"ngrok-skip-browser-warning": "69420"},
          );
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            final list = decoded is List
                ? decoded
                : (decoded['assessments'] ?? decoded['data'] ?? []);
            merged.addAll(
              (list as List).map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        } catch (e) {
          debugPrint("Error fetching assessments for class $classId: $e");
        }
      }
      return merged;
    });
  }

  /// Resolves which test (pre_test/post_test) a raw story-level reading
  /// log belongs to. `test_type` is a direct column on student_progress
  /// itself — confirmed against the `fillable` list and
  /// `completedStoriesFor()` in StudentProgress.php — so it's read
  /// straight off the log first. The other spots are kept as a fallback
  /// only, in case some other endpoint nests it differently; a genuinely
  /// unresolved log falls back to null so callers bucket it under
  /// "Other Reads" rather than guessing wrong.
  String? _resolveLogTestType(dynamic log) {
    if (log is! Map) return null;
    final candidates = [
      log['test_type'], // student_progress.test_type — confirmed field
      log['story_type'],
      (log['pivot'] is Map) ? log['pivot']['test_type'] : null,
      (log['story'] is Map) ? log['story']['story_type'] : null,
      (log['story'] is Map) ? log['story']['test_type'] : null,
    ];
    for (final c in candidates) {
      final s = _safeStr(c).toLowerCase();
      if (s == 'pre_test' || s == 'post_test') return s;
    }
    return null;
  }

  Widget _buildPhilIriComparisonCard(List<Map<String, dynamic>> assessments) {
    Map<String, dynamic>? pre;
    Map<String, dynamic>? post;
    for (final a in assessments) {
      final t = _safeStr(a['test_type']);
      if (t == 'pre_test' && pre == null) pre = a;
      if (t == 'post_test' && post == null) post = a;
    }
    if (pre == null && post == null) return const SizedBox.shrink();

    Widget gradeColumn(String label, dynamic preVal, dynamic postVal) {
      final String preG = _safeStr(preVal, '—');
      final String postG = _safeStr(postVal, '—');
      final num? preNum = num.tryParse(preG);
      final num? postNum = num.tryParse(postG);
      IconData arrow = Icons.remove_rounded;
      Color arrowColor = Colors.black38;
      if (preNum != null && postNum != null) {
        if (postNum > preNum) {
          arrow = Icons.arrow_upward_rounded;
          arrowColor = Colors.green.shade700;
        } else if (postNum < preNum) {
          arrow = Icons.arrow_downward_rounded;
          arrowColor = Colors.red.shade700;
        }
      }
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Gr. $preG",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(arrow, size: 14, color: arrowColor),
                Text(
                  "Gr. $postG",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "📊 Phil-IRI Pre-Test vs Post-Test (Stage 2 GST)",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            "Set ${_safeStr(pre?['set_letter'], '—')} → Set ${_safeStr(post?['set_letter'], '—')}",
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              gradeColumn(
                "Independent",
                pre?['independent_grade'],
                post?['independent_grade'],
              ),
              gradeColumn(
                "Instructional",
                pre?['instructional_grade'],
                post?['instructional_grade'],
              ),
              gradeColumn(
                "Frustration",
                pre?['frustration_grade'],
                post?['frustration_grade'],
              ),
            ],
          ),
          if (pre == null || post == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                pre == null
                    ? "No pre-test Phil-IRI assessment on record yet."
                    : "No post-test Phil-IRI assessment on record yet.",
                style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: Colors.brown.shade700,
                ),
              ),
            ),
        ],
      ),
    );
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

  Future<void> _fetchDashboardData({bool keepStudentCache = false}) async {
    setState(() => _isLoading = true);
    if (!keepStudentCache) {
      // Pull-to-refresh / refresh button: kunin ulit ang bagong progress.
      _progressCache.clear();
      _totalsByStudent.clear();
      _assessmentsFutureCache.clear();
      _rosterFuture = null;
    }
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
        Uri.parse(
          "${widget.baseUrl}/api/teachers/$tId/dashboard-summary?test_type=$_summaryTestType",
        ),
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

  // ==========================================
  // CLASS PERFORMANCE REPORT (PDF)
  // ==========================================
  // Kinukuha ang Pre/Post totals ng BAWAT naka-enroll na estudyante (hindi
  // lang ang mga card na nabuksan na) para kumpleto ang report, tapos
  // binubuksan ang share/save sheet (download sa web).
  Future<void> _exportClassReport() async {
    if (_isExporting) return;
    final messenger = ScaffoldMessenger.of(context);
    final raw = _summaryData['students'];
    if (raw is! List || raw.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Wala pang naka-enroll na estudyante para sa report.'),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final students = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Parehong cache ang gamit ng mga record card, kaya walang doble
      // na request para sa mga nakuha na.
      await Future.wait(students.map((s) => _fetchStudentProgress(s['id'])));

      final rows = students.map((s) {
        final totals = _totalsByStudent[s['id']] ?? const <String, dynamic>{};
        final first = _safeStr(s['first_name']);
        final last = _safeStr(s['last_name']);
        final fullName = '$first $last'.trim();
        return <String, dynamic>{
          'name': _safeStr(
            s['name'],
            fullName.isEmpty ? 'Unnamed student' : fullName,
          ),
          'class_name': _safeStr(
            s['class_name'],
            '${_safeStr(s['grade_level'])} ${_safeStr(s['section'])}'.trim(),
          ),
          'pre': totals['pre_test'],
          'post': totals['post_test'],
        };
      }).toList();

      final bytes = await ClassReportPdf.build(
        students: rows,
        mispronunciations: _mispronunciations,
      );

      final n = DateTime.now();
      final stamp =
          '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'class_reading_report_$stamp.pdf',
      );
    } catch (e) {
      debugPrint('Error creating class report: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Hindi nagawa ang report. Subukan ulit.')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Download class report (PDF)",
            onPressed: _exportClassReport,
          ),
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
                      const SizedBox(height: 8),
                      PhilIriTestTypeFilter(
                        value: _summaryTestType,
                        onChanged: (v) {
                          if (v == _summaryTestType) return;
                          setState(() => _summaryTestType = v);
                          _fetchDashboardData(keepStudentCache: true);
                        },
                      ),
                      const SizedBox(height: 12),

                      const SizedBox(height: 20),
                      _buildClassLevelChart(),
                      const SizedBox(height: 16),
                      PhilIriAnalyticsPanel(
                        summary: _summaryData,
                        testType: _summaryTestType,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isExporting ? null : _exportClassReport,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _isExporting
                              ? "Gumagawa ng report..."
                              : "Download class report (PDF)",
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStudentRoster(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ==========================================
  // STUDENT ROSTER — isang simpleng row kada naka-enroll na estudyante.
  // Pag-tap, bubukas ang buong record ng estudyante.
  // ==========================================
  static const Color _lvIndependent = Color(0xFF4CAF50);
  static const Color _lvInstructional = Color(0xFFFFA726);
  static const Color _lvFrustration = Color(0xFFE53935);

  Color _lvColor(String k) => k == 'independent'
      ? _lvIndependent
      : k == 'instructional'
      ? _lvInstructional
      : k == 'frustration'
      ? _lvFrustration
      : Colors.black26;

  String _lvLabel(String k) => k == 'independent'
      ? 'Independent'
      : k == 'instructional'
      ? 'Instructional'
      : k == 'frustration'
      ? 'Frustration'
      : '';

  Map<String, dynamic> _rosterTest(dynamic id, String key) {
    final t = _totalsByStudent[id]?[key];
    return t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
  }

  bool _rosterHas(Map<String, dynamic> t) =>
      (num.tryParse('${t['stories'] ?? 0}') ?? 0) > 0;

  String _rosterLevel(Map<String, dynamic> t) {
    if (!_rosterHas(t)) return '';
    final lv = '${t['level'] ?? ''}'.toLowerCase();
    return const ['independent', 'instructional', 'frustration'].contains(lv)
        ? lv
        : '';
  }

  double? _rosterWordChange(
    Map<String, dynamic> pre,
    Map<String, dynamic> post,
  ) {
    if (!_rosterHas(pre) || !_rosterHas(post)) return null;
    final a = double.tryParse('${pre['word_pct']}');
    final b = double.tryParse('${post['word_pct']}');
    return (a == null || b == null) ? null : b - a;
  }

  String _studentName(Map<String, dynamic> s) {
    final full = '${_safeStr(s['first_name'])} ${_safeStr(s['last_name'])}'
        .trim();
    return _safeStr(s['name'], full.isEmpty ? 'Unnamed student' : full);
  }

  String _studentClass(Map<String, dynamic> s) => _safeStr(
    s['class_name'],
    '${_safeStr(s['grade_level'])} ${_safeStr(s['section'])}'.trim(),
  );

  void _openStudent(Map<String, dynamic> s) {
    final id = int.tryParse('${s['id']}');
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProgressScreen(
          studentId: id,
          baseUrl: widget.baseUrl,
          studentName: _studentName(s),
        ),
      ),
    );
  }

  Widget _rosterLevelTag(String label, String lv) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _lvColor(lv), shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        lv.isEmpty ? '$label: no test yet' : '$label: ${_lvLabel(lv)}',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );

  Widget _rosterRow(Map<String, dynamic> s) {
    final pre = _rosterTest(s['id'], 'pre_test');
    final post = _rosterTest(s['id'], 'post_test');
    final change = _rosterWordChange(pre, post);
    final cls = _studentClass(s);

    String changeText = '--';
    Color changeColor = Colors.black38;
    if (change != null) {
      final v = change % 1 == 0
          ? change.toStringAsFixed(0)
          : change.toStringAsFixed(1);
      changeText = change >= 0 ? '+$v%' : '$v%';
      changeColor = change < 0 ? _lvFrustration : _lvIndependent;
    }

    return InkWell(
      onTap: () => _openStudent(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _studentName(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (cls.isNotEmpty)
                    Text(
                      cls,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _rosterLevelTag('Pre', _rosterLevel(pre)),
                      _rosterLevelTag('Post', _rosterLevel(post)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  changeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: changeColor,
                  ),
                ),
                const Text(
                  'word reading',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRoster() {
    final raw = _summaryData['students'];
    if (raw is! List || raw.isEmpty) {
      return const Text(
        "No students enrolled yet.",
        style: TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final students = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    _rosterFuture ??= Future.wait(
      students.map((s) => _fetchStudentProgress(s['id'])),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Students (${students.length})",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          const Text(
            "Pre-test and post-test. Needs help first. Tap a student for the full record.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<List<dynamic>>>(
            future: _rosterFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Students who need the most support first (by post-test
              // level), then students with no post-test yet; ties by name.
              int priority(Map<String, dynamic> s) {
                final lv = _rosterLevel(_rosterTest(s['id'], 'post_test'));
                return lv == 'frustration'
                    ? 0
                    : lv == 'instructional'
                    ? 1
                    : lv == 'independent'
                    ? 2
                    : 3;
              }

              final sorted = [...students]
                ..sort((a, b) {
                  final p = priority(a).compareTo(priority(b));
                  if (p != 0) return p;
                  return _studentName(
                    a,
                  ).toLowerCase().compareTo(_studentName(b).toLowerCase());
                });

              return Column(
                children: [
                  for (int i = 0; i < sorted.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.07),
                      ),
                    _rosterRow(sorted[i]),
                  ],
                ],
              );
            },
          ),
        ],
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
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchStudentAssessments(student),
          builder: (context, assessSnapshot) {
            final List<Map<String, dynamic>> assessments =
                assessSnapshot.data ?? const [];
            return _buildLearnerRecordCardContent(
              student,
              snapshot.data ?? const [],
              assessments,
            );
          },
        );
      },
    );
  }

  Widget _buildLearnerRecordCardContent(
    Map<String, dynamic> student,
    List progressLogs,
    List<Map<String, dynamic>> assessments,
  ) {
    List studentMispronunciations = _mispronunciations
        .where((m) => m['student_id'].toString() == student['id'].toString())
        .toList();

    List studentSelfCorrections = _selfCorrections
        .where((m) => m['student_id'].toString() == student['id'].toString())
        .toList();

    // Split reading records into Pre-Test / Post-Test / Other Reads so
    // they're compared separately below, instead of lumped together.
    final List preTestLogs = [];
    final List postTestLogs = [];
    final List otherLogs = [];
    for (final log in progressLogs) {
      final t = _resolveLogTestType(log);
      if (t == 'pre_test') {
        preTestLogs.add(log);
      } else if (t == 'post_test') {
        postTestLogs.add(log);
      } else {
        otherLogs.add(log);
      }
    }

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
          _buildPhilIriComparisonCard(assessments),
          _buildStudentTotals(student['id']),
          if (progressLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.amber.shade200,
              child: const Text(
                "No reading records yet.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            _buildReadingRecordsSection(
              "📝",
              "PRE-TEST",
              preTestLogs,
              studentMispronunciations,
              studentSelfCorrections,
            ),
            _buildReadingRecordsSection(
              "✅",
              "POST-TEST",
              postTestLogs,
              studentMispronunciations,
              studentSelfCorrections,
            ),
            _buildReadingRecordsSection(
              "📚",
              "OTHER READS",
              otherLogs,
              studentMispronunciations,
              studentSelfCorrections,
            ),
          ],
        ],
      ),
    );
  }

  /// One story-level reading-records table (Pre-Test / Post-Test / Other
  /// Reads sections all reuse this), sharing the row-building logic the
  /// single combined table used to use.
  Widget _buildReadingRecordsTable(
    List logs,
    List studentMispronunciations,
    List studentSelfCorrections,
  ) {
    return Table(
      border: TableBorder.all(color: Colors.brown, width: 2),
      columnWidths: const {
        0: FlexColumnWidth(1.8),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(2.5), // Expanded space for playable Audio Chips
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
        ...logs.map((log) {
          List storyWords = studentMispronunciations
              .where(
                (m) => m['story_id'].toString() == log['story_id'].toString(),
              )
              .toList();

          List storySelfCorrections = studentSelfCorrections
              .where(
                (m) => m['story_id'].toString() == log['story_id'].toString(),
              )
              .toList();

          String selfCorrectedText = storySelfCorrections.isEmpty
              ? "None"
              : storySelfCorrections
                    .map((w) => "${w['word']} (${w['total_attempts']}x)")
                    .join(", ");

          String wpmValue = log['wpm'] != null
              ? "${(log['wpm'] as num).round()}"
              : 'N/A';
          String accuracyValue = log['oral_fluency_accuracy'] != null
              ? "${log['oral_fluency_accuracy']}%"
              : 'N/A';
          String totalWords = log['total_words']?.toString() ?? '?';
          if (totalWords == '0') totalWords = '?';
          String correctWords =
              (log['correct_words_count'] ?? log['correct_words'])
                  ?.toString() ??
              '?';
          if (totalWords == '?') correctWords = '?';
          String miscuesCount = log['miscues_count']?.toString() ?? '?';
          final int qScore = int.tryParse('${log['quiz_score'] ?? 0}') ?? 0;
          final int qTotal =
              int.tryParse('${log['total_questions'] ?? 0}') ?? 0;
          String quizPct = qTotal > 0
              ? ' (${(qScore / qTotal * 100).round()}%)'
              : '';

          String timeSpentDisplay = '? mins';
          if (log['time_on_task'] != null) {
            int seconds = int.tryParse(log['time_on_task'].toString()) ?? 0;
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
                  _safeStr(
                    log['story_title'] ??
                        log['story']?['title'] ??
                        log['title'],
                    'Unknown',
                  ),
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
                          "Word Reading:\n$totalWords words − $miscuesCount miscues = $correctWords correct\n$correctWords ÷ $totalWords × 100 = $accuracyValue",
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
                  "${log['quiz_score'] ?? 0}/${log['total_questions'] ?? 0}$quizPct",
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
                          final int attempts = item['total_attempts'] ?? 3;

                          final bool isThisPlaying =
                              _isPlayingAudio &&
                              _currentlyPlayingUrl == audioUrl;

                          Color chipBg = miscueType == 'omission'
                              ? Colors.grey.shade800
                              : Colors.red.shade900;

                          return InkWell(
                            onTap: audioUrl != null && audioUrl.isNotEmpty
                                ? () => _togglePlayStruggleAudio(audioUrl)
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
    );
  }

  /// A labeled reading-records section (Pre-Test / Post-Test / Other Reads).
  /// Returns nothing when this bucket has no logs, so empty sections don't
  /// leave blank gaps in the card.
  Widget _buildReadingRecordsSection(
    String emoji,
    String title,
    List logs,
    List studentMispronunciations,
    List studentSelfCorrections,
  ) {
    if (logs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              "$emoji $title",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          _buildStoryBarChart(logs),
          const SizedBox(height: 8),
          _buildReadingRecordsTable(
            logs,
            studentMispronunciations,
            studentSelfCorrections,
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

  // ----------------------------------------------------------
  // Pre-Test vs Post-Test totals + per-story chart helpers
  // ----------------------------------------------------------
  double _numOf(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  String _pct1(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Color _lvlColor(String level) {
    final l = level.toLowerCase();
    if (l.contains('independent')) return const Color(0xFF4CAF50);
    if (l.contains('instructional')) return const Color(0xFFFFA726);
    return const Color(0xFFE53935);
  }

  String _lvlLabel(String level) {
    final l = level.toLowerCase();
    if (l.contains('independent')) return 'Independent';
    if (l.contains('instructional')) return 'Instructional';
    if (l.contains('frustration')) return 'Frustration';
    return '—';
  }

  Widget _buildStudentTotals(dynamic studentId) {
    final totals = _totalsByStudent[studentId];
    if (totals == null) return const SizedBox.shrink();

    Map<String, dynamic> tot(String k) {
      final v = totals[k];
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    }

    final pre = tot('pre_test');
    final post = tot('post_test');
    final bool hasPre = _numOf(pre['stories']) > 0;
    final bool hasPost = _numOf(post['stories']) > 0;
    if (!hasPre && !hasPost) return const SizedBox.shrink();

    const Color preColor = Color(0xFF5C6BC0);
    const Color postColor = Color(0xFF940D0D);

    BarChartRodData rod(double y, Color c) => BarChartRodData(
      toY: y,
      color: c,
      width: 24,
      borderRadius: BorderRadius.circular(4),
    );

    Widget block(String title, Map<String, dynamic> t, Color accent) {
      final bool has = _numOf(t['stories']) > 0;
      final int words = _numOf(t['total_words']).toInt();
      final int quizQ = _numOf(t['quiz_questions']).toInt();
      const TextStyle small = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );
      const TextStyle bold = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
      );
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              if (!has)
                const Text('Wala pang natapos.', style: small)
              else ...[
                Text('Stories: ${_numOf(t['stories']).toInt()}', style: small),
                if (words > 0) ...[
                  Text('Kabuuang salita: $words', style: small),
                  Text(
                    'Miscues: ${_numOf(t['miscues']).toInt()}',
                    style: small,
                  ),
                  Text(
                    'Tamang salita: ${_numOf(t['correct_words']).toInt()}',
                    style: small,
                  ),
                ],
                const SizedBox(height: 6),
                const Text('Word Reading', style: small),
                Text(
                  words > 0
                      ? '${_numOf(t['correct_words']).toInt()} ÷ $words × 100 = ${_pct1(_numOf(t['word_pct']))}%'
                      : '${_pct1(_numOf(t['word_pct']))}% (average)',
                  style: bold,
                ),
                const SizedBox(height: 4),
                const Text('Comprehension', style: small),
                Text(
                  quizQ > 0
                      ? '${_numOf(t['quiz_correct']).toInt()} ÷ $quizQ × 100 = ${_pct1(_numOf(t['comp_pct']))}%'
                      : '${_pct1(_numOf(t['comp_pct']))}% (average)',
                  style: bold,
                ),
                const SizedBox(height: 6),
                Text(
                  _lvlLabel('${t['level'] ?? ''}'),
                  style: TextStyle(
                    color: _lvlColor('${t['level'] ?? ''}'),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    String? gain;
    if (hasPre && hasPost) {
      String sign(double d) => d >= 0 ? '+${_pct1(d)}' : _pct1(d);
      gain =
          'Pagbabago (Post − Pre): Word Reading '
          '${sign(_numOf(post['word_pct']) - _numOf(pre['word_pct']))}% • '
          'Comprehension '
          '${sign(_numOf(post['comp_pct']) - _numOf(pre['comp_pct']))}%';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 PRE-TEST vs POST-TEST (KABUUAN)',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const Text(
            'Total ng lahat ng stories sa bawat test, hindi average ng %.',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barsSpace: 6,
                    barRods: [
                      rod(_numOf(pre['word_pct']), preColor),
                      rod(_numOf(post['word_pct']), postColor),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barsSpace: 6,
                    barRods: [
                      rod(_numOf(pre['comp_pct']), preColor),
                      rod(_numOf(post['comp_pct']), postColor),
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 32,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          value.toInt() == 0
                              ? 'Word Reading %'
                              : 'Comprehension %',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.circle, size: 10, color: preColor),
              SizedBox(width: 4),
              Text('Pre-Test', style: TextStyle(fontSize: 11)),
              SizedBox(width: 14),
              Icon(Icons.circle, size: 10, color: postColor),
              SizedBox(width: 4),
              Text('Post-Test', style: TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block('Pre-Test', pre, preColor),
              const SizedBox(width: 8),
              block('Post-Test', post, postColor),
            ],
          ),
          if (gain != null) ...[
            const SizedBox(height: 10),
            Text(
              gain,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }

  /// Bar chart: isang bar kada story (Word Reading %), kulay ayon sa level.
  Widget _buildStoryBarChart(List logs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = logs.length * 52.0 > c.maxWidth
              ? logs.length * 52.0
              : c.maxWidth;
          const Color line = Colors.black45;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Word Reading % bawat story (guhit: 90% at 97%)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  height: 170,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 100,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 90,
                            color: line,
                            strokeWidth: 1,
                            dashArray: [5, 4],
                          ),
                          HorizontalLine(
                            y: 97,
                            color: line,
                            strokeWidth: 1,
                            dashArray: [5, 4],
                          ),
                        ],
                      ),
                      barGroups: [
                        for (int i = 0; i < logs.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: _numOf(
                                  logs[i]['oral_fluency_accuracy'],
                                ).clamp(0.0, 100.0),
                                width: 20,
                                color: _lvlColor(
                                  '${logs[i]['reading_level'] ?? ''}',
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            reservedSize: 32,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '#${value.toInt() + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
