import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isExporting = false; // gumagawa ng class PDF report
  Future<List<List<dynamic>>>? _rosterFuture; // totals ng lahat ng estudyante
  final TextEditingController _rosterSearch = TextEditingController();
  String _rosterFilter = 'all'; // all | needs_help | improved | no_post
  int? _selectedStudentId; // para sa master-detail sa malapad na screen

  final Map<dynamic, Future<List<dynamic>>> _progressCache = {};
  final Map<dynamic, Map<String, dynamic>> _totalsByStudent = {};
  final Map<dynamic, List<dynamic>> _recordsByStudent = {};

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
            _recordsByStudent[studentId] = decoded['data'] as List<dynamic>;
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
  }

  Future<void> _fetchDashboardData({bool keepStudentCache = false}) async {
    setState(() => _isLoading = true);
    if (!keepStudentCache) {
      // Pull-to-refresh / refresh button: kunin ulit ang bagong progress.
      _progressCache.clear();
      _totalsByStudent.clear();
      _recordsByStudent.clear();
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

      if (summaryRes.statusCode == 200 &&
          mispronunciationRes.statusCode == 200 &&
          mounted) {
        final decodedSummary = jsonDecode(summaryRes.body);
        final decodedMispro = jsonDecode(mispronunciationRes.body);

        setState(() {
          _summaryData = decodedSummary['data'] ?? decodedSummary;
          _mispronunciations =
              decodedMispro['data'] ?? decodedMispro['mispronunciations'] ?? [];
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
    _rosterSearch.dispose();
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
            onPressed: _isExporting ? null : _exportClassReport,
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
                      PhilIriTestTypeFilter(
                        value: _summaryTestType,
                        onChanged: (v) {
                          if (v == _summaryTestType) return;
                          setState(() => _summaryTestType = v);
                          _fetchDashboardData(keepStudentCache: true);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildLevelSummary(),
                      const SizedBox(height: 16),
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

  String _studentLrn(Map<String, dynamic> s) => _safeStr(s['lrn']);

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  double? _changeOf(Map<String, dynamic> s) => _rosterWordChange(
    _rosterTest(s['id'], 'pre_test'),
    _rosterTest(s['id'], 'post_test'),
  );

  // "Needs help": parehong rule ng Alerts tab (AlertController) -- ang
  // huling 2 natapos na story ay parehong Frustration. Kailangan ng hindi
  // bababa sa 2 story.
  bool _needsHelp(Map<String, dynamic> s) {
    final recs = _recordsByStudent[s['id']] ?? const <dynamic>[];
    if (recs.length < 2) return false;
    return recs
        .sublist(recs.length - 2)
        .every(
          (r) =>
              '${r['reading_level'] ?? ''}'.trim().toLowerCase() ==
              'frustration',
        );
  }

  bool _rosterMatches(Map<String, dynamic> s) {
    final q = _rosterSearch.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${_studentName(s)} ${_studentLrn(s)}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    final post = _rosterTest(s['id'], 'post_test');
    switch (_rosterFilter) {
      case 'needs_help':
        return _needsHelp(s);
      case 'improved':
        final ch = _changeOf(s);
        return ch != null && ch > 0;
      case 'no_post':
        return !_rosterHas(post);
      default:
        return true;
    }
  }

  // Malapad (laptop/tablet landscape) -> ipapakita sa kanang pane.
  // Makitid (phone) -> bubukas ang bagong screen.
  void _openStudent(Map<String, dynamic> s, {required bool wide}) {
    final id = int.tryParse('${s['id']}');
    if (id == null) return;
    if (wide) {
      setState(() => _selectedStudentId = id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProgressScreen(
          studentId: id,
          baseUrl: widget.baseUrl,
          studentName: _studentName(s),
          teacherView: true,
          lrn: _studentLrn(s),
          className: _studentClass(s),
        ),
      ),
    );
  }

  Widget _levelPill(String lv) {
    final bool none = lv.isEmpty;
    final Color c = none ? Colors.black45 : _lvColor(lv);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: none
            ? Colors.black.withValues(alpha: 0.05)
            : c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        none ? 'No post-test yet' : _lvLabel(lv),
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }

  Widget _rosterRow(Map<String, dynamic> s, {required bool wide}) {
    final id = int.tryParse('${s['id']}');
    final bool selected = wide && id != null && id == _selectedStudentId;
    final post = _rosterTest(s['id'], 'post_test');
    final change = _changeOf(s);
    final name = _studentName(s);
    final lrn = _studentLrn(s);
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

    return Material(
      color: selected ? const Color(0xFFE8F1FB) : Colors.transparent,
      child: InkWell(
        onTap: () => _openStudent(s, wide: wide),
        hoverColor: const Color(0xFFF1F6FC),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD6E6FA),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Color(0xFF1F4E8C),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (lrn.isNotEmpty || cls.isNotEmpty)
                      Text(
                        lrn.isNotEmpty ? 'LRN $lrn' : cls,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _levelPill(_rosterLevel(post)),
                  const SizedBox(height: 4),
                  Text(
                    changeText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
              if (!wide) const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rosterCardShell({required Widget child}) => Container(
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
    child: child,
  );

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

    return LayoutBuilder(
      builder: (context, box) {
        final bool wide = box.maxWidth >= 900;

        return FutureBuilder<List<List<dynamic>>>(
          future: _rosterFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _rosterCardShell(
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                ),
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

            final visible = sorted.where(_rosterMatches).toList();

            Widget chip(String key, String label) => ChoiceChip(
              label: Text(label),
              selected: _rosterFilter == key,
              onSelected: (_) => setState(() => _rosterFilter = key),
            );

            final Widget topPart = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Students",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "${students.length} enrolled",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rosterSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search student or LRN',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    chip('all', 'All'),
                    chip('needs_help', 'Needs help'),
                    chip('improved', 'Improved'),
                    chip('no_post', 'No post-test'),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            );

            final Widget emptyMsg = const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No students match.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );

            Widget divider() =>
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.07));

            // ---- Phone: isang column, bubukas ang bagong screen -----------
            if (!wide) {
              return _rosterCardShell(
                child: Column(
                  children: [
                    topPart,
                    if (visible.isEmpty) emptyMsg,
                    for (int i = 0; i < visible.length; i++) ...[
                      if (i > 0) divider(),
                      _rosterRow(visible[i], wide: false),
                    ],
                  ],
                ),
              );
            }

            // ---- Laptop: roster sa kaliwa, profile sa kanan ---------------
            final double h = (MediaQuery.of(context).size.height - 160)
                .clamp(520.0, 900.0)
                .toDouble();

            Map<String, dynamic>? selected;
            for (final s in students) {
              if (int.tryParse('${s['id']}') == _selectedStudentId) {
                selected = s;
              }
            }

            return SizedBox(
              height: h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 380,
                    child: _rosterCardShell(
                      child: Column(
                        children: [
                          topPart,
                          Expanded(
                            child: visible.isEmpty
                                ? emptyMsg
                                : ListView.separated(
                                    itemCount: visible.length,
                                    separatorBuilder: (context, index) =>
                                        divider(),
                                    itemBuilder: (_, i) =>
                                        _rosterRow(visible[i], wide: true),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: selected == null
                        ? _rosterCardShell(
                            child: const Center(
                              child: Text(
                                'Select a student to see their progress.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          )
                        : StudentProgressScreen(
                            key: ValueKey(_selectedStudentId),
                            studentId: _selectedStudentId!,
                            baseUrl: widget.baseUrl,
                            studentName: _studentName(selected),
                            teacherView: true,
                            embedded: true,
                            lrn: _studentLrn(selected),
                            className: _studentClass(selected),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _safeStr(dynamic value, [String fallback = ""]) {
    if (value == null) return fallback;
    final str = value.toString();
    if (str.isEmpty || str == "null") return fallback;
    return str;
  }

  // Basic class overview: how many students sit at each Phil-IRI level for the
  // selected test, plus how many have no result yet.
  Widget _buildLevelSummary() {
    final raw = _summaryData['students'];
    final int total = raw is List ? raw.length : 0;
    int count(String k) =>
        (num.tryParse('${_summaryData['${k}_count'] ?? 0}') ?? 0).toInt();

    final int frustration = count('frustration');
    final int instructional = count('instructional');
    final int independent = count('independent');
    final int noResult = (total - frustration - instructional - independent)
        .clamp(0, total);

    Widget tile(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    return _rosterCardShell(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _summaryTestType == 'pre_test'
                  ? 'Pre-test results'
                  : 'Post-test results',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              '$total students',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                tile('Frustration', frustration, _lvFrustration),
                tile('Instructional', instructional, _lvInstructional),
                tile('Independent', independent, _lvIndependent),
                tile('No result yet', noResult, Colors.black45),
              ],
            ),
          ],
        ),
      ),
    );
  }
}