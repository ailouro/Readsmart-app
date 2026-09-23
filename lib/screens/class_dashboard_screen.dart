import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:confetti/confetti.dart';
import '../services/config.dart';
import '../widgets/responsive_layout.dart';
import 'story_view_screen.dart';
import 'assessment_flow_screen.dart';
import '../services/phil_iri_session.dart';
import '../services/phil_iri_rules.dart';
import '../services/bgm_service.dart';

String _safeString(dynamic value, [String fallback = ""]) {
  if (value == null) return fallback;
  final String str = value.toString();
  if (str == "null" || str == "undefined") return fallback;
  return str;
}

class ClassDashboardScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String classCode;
  final bool isTeacher;
  final int studentId;

  const ClassDashboardScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.studentId,
    this.classCode = '',
    this.isTeacher = false,
  });

  @override
  State<ClassDashboardScreen> createState() => _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends State<ClassDashboardScreen> {
  // Matched Comic Themes
  static const Color maroonTheme = Color(0xFF9B0505);
  static const Color accentTheme = Color(0xFFFDE047);
  static const Color cyanAccent = Color(0xFFAFE1EE);
  static const Color backgroundColor = Color(0xFFFAF6F6);

  bool _isLoading = true;
  Map<String, dynamic>? _classDetails;
  List<dynamic> _students = [];
  List<dynamic> _assignedStories = [];

  // Phil-IRI reading assessments assigned to this student in this class.
  // Each one replaces the individual story missions of its test type.
  List<Map<String, dynamic>> _assessments = [];

  final TextEditingController _studentSearchController =
      TextEditingController();
  String _studentSearchQuery = '';

  final TextEditingController _missionSearchController =
      TextEditingController();
  String _missionSearchQuery = '';
  // 'all' | 'pre_test' | 'post_test' | 'completed'
  String _missionFilter = 'all';

  // Post-test missions stay locked until every pre-test mission is fully
  // done (reading + quiz if it has one). The unlock celebration should only
  // fire once, the moment it actually flips from locked to unlocked — not
  // every time the student reopens a class that was already unlocked.
  late ConfettiController _confettiController;
  bool _hasCheckedUnlockOnLoad = false;

  String get _postTestUnlockedPrefsKey =>
      'class_${widget.classId}_student_${widget.studentId}_post_test_unlocked_celebrated';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _fetchClassDetails();
    _studentSearchController.addListener(() {
      setState(() {
        _studentSearchQuery = _studentSearchController.text
            .trim()
            .toLowerCase();
      });
    });
    _missionSearchController.addListener(() {
      setState(() {
        _missionSearchQuery = _missionSearchController.text
            .trim()
            .toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _missionSearchController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // Same completion logic used by the mission card badges, reused here so
  // the search/filter/progress summary always agree with what each card shows.
  String _missionTestType(dynamic story) {
    if (story['pivot'] != null && story['pivot']['test_type'] != null) {
      return story['pivot']['test_type'];
    }
    return "post_test";
  }

  bool _isMissionReadingDone(
    dynamic story,
    String tType,
    SharedPreferences? prefs,
  ) {
    final progress = story['student_progress'];
    final bool isReadingCompleted =
        progress != null &&
        (progress['is_reading_completed'] == 1 ||
            progress['is_reading_completed'] == true);
    final bool isLocallyReadingCompleted =
        prefs?.getBool('story_${story['id']}_${tType}_reading_completed') ??
        false;
    return isReadingCompleted || isLocallyReadingCompleted;
  }

  // A mission counts as fully done for unlock-gating purposes once reading
  // is finished AND, if it has a quiz attached, the quiz has been taken too
  // — matching what the card's own "Quiz Score" / "Read Completed" badge
  // already shows, so the gate never disagrees with what the student sees.
  bool _isMissionFullyDone(
    dynamic story,
    String tType,
    SharedPreferences? prefs,
  ) {
    final bool readingDone = _isMissionReadingDone(story, tType, prefs);
    if (!readingDone) return false;

    final bool hasQuiz = story['quiz'] != null;
    if (!hasQuiz) return true;

    final progress = story['student_progress'];
    final bool hasQuizScore =
        progress != null && progress['quiz_score'] != null;
    final bool hasLocalQuizScore =
        prefs?.getInt('story_${story['id']}_${tType}_quiz_score') != null;
    return hasQuizScore || hasLocalQuizScore;
  }

  /// Checks (once per build where prefs are available) whether Post-Test
  /// missions just became unlocked, and if so — and only the first time —
  /// shows the celebration popup with confetti and remembers that it's been
  /// shown so it never repeats on later visits.
  Future<void> _maybeCelebratePostTestUnlock(
    bool allPreTestDone,
    SharedPreferences? prefs,
  ) async {
    if (!allPreTestDone || prefs == null || _hasCheckedUnlockOnLoad) return;
    _hasCheckedUnlockOnLoad = true;

    final bool alreadyCelebrated =
        prefs.getBool(_postTestUnlockedPrefsKey) ?? false;
    if (alreadyCelebrated) return;

    await prefs.setBool(_postTestUnlockedPrefsKey, true);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confettiController.play();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.black, width: 3.5),
                ),
                backgroundColor: accentTheme,
                title: const Text(
                  "Post-Test Unlocked! 🚀",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                content: const Text(
                  "Great job finishing all the Pre-Test missions! The "
                  "Post-Test missions are now open for you to play.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: maroonTheme,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Colors.black,
                            width: 2.5,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        "Let's Go!",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                maxBlastForce: 25,
                minBlastForce: 5,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ],
          );
        },
      );
    });
  }

  List<dynamic> get _filteredStudents {
    if (_studentSearchQuery.isEmpty) return _students;
    return _students.where((student) {
      final name = (student['name'] ?? student['username'] ?? '')
          .toString()
          .toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      return name.contains(_studentSearchQuery) ||
          email.contains(_studentSearchQuery);
    }).toList();
  }

  Future<void> _fetchClassDetails() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch main class details
      final response = await http.get(
        Uri.parse("$baseUrl/api/classes/${widget.classId}"),
        headers: networkHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        setState(() {
          _classDetails = data;
          _students = data['students'] ?? [];
          _assignedStories = data['stories'] ?? data['assigned_stories'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching class details: $e");
    }

    try {
      // 2. Safely fetch stories without overwriting valid data with empty arrays
      final resStories = await http.get(
        Uri.parse(
          "$baseUrl/api/classes/${widget.classId}/stories?student_id=${widget.studentId}",
        ),
        headers: networkHeaders,
      );

      if (resStories.statusCode == 200 && mounted) {
        final decoded = jsonDecode(resStories.body);
        final list = decoded is List
            ? decoded
            : (decoded['stories'] ?? decoded['data'] ?? []);

        setState(() {
          if (list.isNotEmpty) {
            _assignedStories = list;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching stories: $e");
    }

    try {
      // 3. Phil-IRI assessments for this student. Optional: if the endpoint
      // is missing or returns nothing, the class works exactly as before.
      final resAssessments = await http.get(
        Uri.parse(
          "$baseUrl/api/classes/${widget.classId}/assessments?student_id=${widget.studentId}",
        ),
        headers: networkHeaders,
      );

      if (resAssessments.statusCode == 200 && mounted) {
        final decoded = jsonDecode(resAssessments.body);
        final list = decoded is List
            ? decoded
            : (decoded['assessments'] ?? decoded['data'] ?? []);
        setState(() {
          _assessments = (list as List)
              .whereType<Map>()
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching assessments: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ---------------------------------------------------------------------
  // Phil-IRI assessment helpers
  // ---------------------------------------------------------------------

  int? _toInt(dynamic value) =>
      value == null ? null : int.tryParse(value.toString());

  Map<String, dynamic>? _assessmentFor(String testType) {
    for (final a in _assessments) {
      if (_safeString(a['test_type']) == testType) return a;
    }
    return null;
  }

  // Respects the search box and the Completed filter, like story missions do.
  Map<String, dynamic>? _visibleAssessment(
    String testType,
    SharedPreferences? prefs,
  ) {
    final a = _assessmentFor(testType);
    if (a == null) return null;
    if (_missionSearchQuery.isNotEmpty &&
        !'reading test'.contains(_missionSearchQuery)) {
      return null;
    }
    if (_missionFilter == 'completed' &&
        !_assessmentIsDone(_assessmentStatus(a, prefs))) {
      return null;
    }
    return a;
  }

  // Same key AssessmentFlowScreen saves its session under.
  String _assessmentPrefsKey(Map<String, dynamic> a) =>
      'stage2_${widget.studentId}_${_safeString(a['test_type'])}_${_safeString(a['set_letter'])}';

  /// 'not_started' | 'in_progress' | 'complete' | 'not_needed'.
  /// The server is the source of truth; the locally saved session fills the
  /// gap when a save failed or the student is offline.
  String _assessmentStatus(Map<String, dynamic> a, SharedPreferences? prefs) {
    final String server = _safeString(a['status'], 'not_started');
    // The backend saves 'completed'; accept both spellings so a status
    // change there never silently breaks this check again.
    if (server == 'complete' ||
        server == 'completed' ||
        server == 'not_needed') {
      return server == 'completed' ? 'complete' : server;
    }

    final String? saved = prefs?.getString(_assessmentPrefsKey(a));
    if (saved != null) {
      try {
        final session = PhilIriSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
        if (session.isComplete) return 'complete';
        if (session.history.isNotEmpty) return 'in_progress';
      } catch (_) {}
    }
    return server == 'in_progress' ? 'in_progress' : 'not_started';
  }

  bool _assessmentIsDone(String status) =>
      status == 'complete' || status == 'not_needed';

  // ---------------------------------------------------------------------
  // Teacher: assign a Phil-IRI Pre-Test to one student.
  // ---------------------------------------------------------------------

  /// The class's own grade level (e.g. "Grade 5" -> 5), used as the
  /// student's actual grade when computing the Stage 2 starting grade.
  int? get _classGrade => _toInt(
    RegExp(
      r'\d+',
    ).firstMatch(_safeString(_classDetails?['grade_level']))?.group(0),
  );

  static const List<String> _assessmentSets = ['A', 'B', 'C', 'D'];

  // Same normalization the backend applies (strtoupper(trim(str_ireplace(
  // 'Set', '', ...)))), so "A" and "Set A" compare equal here too.
  String _normalizeSetLetter(String s) => s
      .replaceAll(RegExp('set', caseSensitive: false), '')
      .trim()
      .toUpperCase();

  /// Finds this student's existing assessment (any status) for the given
  /// test_type, from a raw /assessments list. Used so the assign dialog can
  /// warn before silently overwriting one.
  ///
  /// Matches on test_type ALONE, not test_type + set letter: the backend
  /// keeps exactly one row per (class, student, test_type) and always
  /// overwrites that row regardless of which set letter is submitted, so a
  /// teacher picking a different set for an already-assigned or
  /// already-completed test would otherwise get no warning at all before
  /// its saved outcome is erased.
  Map<String, dynamic>? _findMatchingAssessment(
    List<dynamic> all,
    String testType,
  ) {
    for (final raw in all) {
      if (raw is! Map) continue;
      final a = Map<String, dynamic>.from(raw);
      if (_safeString(a['test_type']) != testType) continue;
      return a;
    }
    return null;
  }

  /// [newSet] is whatever set letter is currently selected in the dialog.
  /// When it differs from the existing row's set, the message calls that
  /// out explicitly — the backend keeps one row per test_type, so
  /// reassigning always switches that row to [newSet], not just refreshes
  /// the same one.
  String _describeExistingAssessment(Map<String, dynamic> a, String newSet) {
    final status = _safeString(a['status'], 'assigned');
    final label = _safeString(a['test_type']) == 'pre_test'
        ? 'Pre-Test'
        : 'Post-Test';
    final set = _safeString(a['set_letter']);
    final switching = _normalizeSetLetter(set) != _normalizeSetLetter(newSet);
    final switchNote = switching ? ' It will be switched to Set $newSet.' : '';
    if (status == 'completed' || status == 'complete') {
      final parts = <String>[];
      if (a['independent_grade'] != null) {
        parts.add('Independent Gr. ${a['independent_grade']}');
      }
      if (a['instructional_grade'] != null) {
        parts.add('Instructional Gr. ${a['instructional_grade']}');
      }
      if (a['frustration_grade'] != null) {
        parts.add('Frustration Gr. ${a['frustration_grade']}');
      }
      if (a['below_range'] == true) parts.add('below range');
      if (a['above_range'] == true) parts.add('above range');
      final detail = parts.isEmpty ? '' : ' (${parts.join(', ')})';
      return 'Already completed this $label, Set $set$detail.$switchNote';
    }
    return 'Already assigned this $label, Set $set — not yet completed.'
        '$switchNote';
  }

  /// Checks whether a Stage 2 passage already exists for this grade, so the
  /// teacher can be warned before assigning a test that will stall.
  /// Fails open (returns true) on a network error so a hiccup here never
  /// blocks a legitimate assignment.
  Future<bool> _passageExistsFor({
    required String testType,
    required String setLetter,
    required int grade,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/api/assessment-passage"
          "?test_type=$testType"
          "&set_letter=${Uri.encodeQueryComponent(setLetter)}"
          "&grade=$grade",
        ),
        headers: networkHeaders,
      );
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      final story = decoded is Map ? decoded['story'] : null;
      final pages = story is Map ? story['pages'] : null;
      return pages is List && pages.isNotEmpty;
    } catch (e) {
      debugPrint("Passage availability check failed: $e");
      return true;
    }
  }

  Future<bool?> _confirmAssignDespiteWarning(
    BuildContext context,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Heads up"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Assign Anyway"),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignAssessmentDialog(Map<String, dynamic> student) async {
    final int? studentId = _toInt(student['id']);
    if (studentId == null) return;

    final String studentName =
        student['name'] ?? student['username'] ?? 'this student';
    final int? classGrade = _classGrade;

    final gstController = TextEditingController();
    String selectedTestType = 'pre_test';
    String selectedSet = _assessmentSets.first;
    // Post-test has no GST score. The manual gives no rule for where a
    // post-test should start, so the teacher chooses the grade directly.
    // Reusing the class grade as the default is a reasonable starting
    // point, not a Phil-IRI requirement.
    int postTestStartGrade = (classGrade ?? PhilIriRules.minGrade).clamp(
      PhilIriRules.minGrade,
      PhilIriRules.maxGrade,
    );
    bool isSubmitting = false;
    String? errorText;

    // #3: existing-assignment visibility. Fetched once when the dialog
    // first builds, so the teacher sees current status before they can
    // accidentally overwrite an in-progress or completed attempt.
    bool existingFetchStarted = false;
    bool existingLoaded = false;
    List<dynamic> existingForStudent = [];
    bool confirmReassign = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (!existingFetchStarted) {
            existingFetchStarted = true;
            () async {
              List<dynamic> list = [];
              try {
                final res = await http.get(
                  Uri.parse(
                    "$baseUrl/api/classes/${widget.classId}/assessments"
                    "?student_id=$studentId",
                  ),
                  headers: networkHeaders,
                );
                if (res.statusCode == 200) {
                  final decoded = jsonDecode(res.body);
                  list = decoded is Map
                      ? ((decoded['assessments'] ?? decoded['data'] ?? [])
                            as List)
                      : (decoded is List ? decoded : []);
                }
              } catch (e) {
                debugPrint("Error fetching existing assessments: $e");
              }
              if (mounted) {
                try {
                  setDialogState(() {
                    existingForStudent = list;
                    existingLoaded = true;
                  });
                } catch (_) {}
              }
            }();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.black, width: 3.5),
            ),
            backgroundColor: accentTheme,
            title: const Text(
              "Assign Reading Test",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "For $studentName"
                    "${classGrade != null ? ' (Grade $classGrade)' : ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pre_test', label: Text('Pre-Test')),
                      ButtonSegment(
                        value: 'post_test',
                        label: Text('Post-Test'),
                      ),
                    ],
                    selected: {selectedTestType},
                    onSelectionChanged: isSubmitting
                        ? null
                        : (v) => setDialogState(() {
                            selectedTestType = v.first;
                            errorText = null;
                            confirmReassign = false;
                          }),
                  ),
                  const SizedBox(height: 16),
                  if (selectedTestType == 'pre_test')
                    TextField(
                      controller: gstController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "GST raw score (0-20)",
                        errorText: errorText,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      value: postTestStartGrade,
                      decoration: InputDecoration(
                        labelText: "Starting Grade",
                        errorText: errorText,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        for (
                          int g = PhilIriRules.minGrade;
                          g <= PhilIriRules.maxGrade;
                          g++
                        )
                          DropdownMenuItem(value: g, child: Text("Grade $g")),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            postTestStartGrade = v;
                            errorText = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "The manual has no fixed rule for the post-test starting "
                      "grade. Many teachers reuse the grade the pre-test "
                      "settled on.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSet,
                    decoration: InputDecoration(
                      labelText: "Passage Set",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _assessmentSets
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text("Set $s")),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedSet = v;
                          errorText = null;
                          confirmReassign = false;
                        });
                      }
                    },
                  ),
                  Builder(
                    builder: (_) {
                      if (!existingLoaded) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Checking existing assignments...",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final match = _findMatchingAssessment(
                        existingForStudent,
                        selectedTestType,
                      );
                      if (match == null) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade700),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _describeExistingAssessment(match, selectedSet),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: confirmReassign,
                              onChanged: (v) => setDialogState(
                                () => confirmReassign = v ?? false,
                              ),
                              title: const Text(
                                "Reassign anyway (erases the saved result)",
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: maroonTheme),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => errorText = null);

                        if (classGrade == null) {
                          setDialogState(
                            () => errorText =
                                "This class has no grade level set.",
                          );
                          return;
                        }

                        int? gstRaw;
                        if (selectedTestType == 'pre_test') {
                          gstRaw = int.tryParse(gstController.text.trim());
                          if (gstRaw == null || gstRaw < 0 || gstRaw > 20) {
                            setDialogState(
                              () =>
                                  errorText = "Enter a GST score from 0 to 20.",
                            );
                            return;
                          }
                        }

                        // #3: don't silently overwrite an existing
                        // assignment/outcome for this test_type — the
                        // backend keeps one row per test_type and always
                        // overwrites it, regardless of set letter, so this
                        // has to fire even when selectedSet differs from
                        // whatever set the existing row is on.
                        final existingMatch = existingLoaded
                            ? _findMatchingAssessment(
                                existingForStudent,
                                selectedTestType,
                              )
                            : null;
                        if (existingMatch != null && !confirmReassign) {
                          setDialogState(
                            () => errorText =
                                'Check "Reassign anyway" above to confirm — '
                                'this student already has that test.',
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        // #2: warn (don't block) if no passage exists yet for
                        // the computed starting grade, so the teacher isn't
                        // blindsided by a student who stalls on step one.
                        int? checkGrade;
                        if (selectedTestType == 'pre_test') {
                          final session = PhilIriSession.forPreTest(
                            studentId: studentId,
                            studentGrade: classGrade,
                            gstRaw: gstRaw!,
                            setLetter: selectedSet,
                          );
                          if (session == null) {
                            final proceed = await _confirmAssignDespiteWarning(
                              dialogContext,
                              "This student's GST score ($gstRaw) is at or "
                              "above the cutoff of 14, so the manual says "
                              "no further testing is needed. Assign the "
                              "pre-test anyway?",
                            );
                            if (proceed != true) {
                              setDialogState(() => isSubmitting = false);
                              return;
                            }
                          } else {
                            checkGrade = session.startGrade;
                          }
                        } else {
                          checkGrade = postTestStartGrade;
                        }

                        if (checkGrade != null) {
                          final exists = await _passageExistsFor(
                            testType: selectedTestType,
                            setLetter: selectedSet,
                            grade: checkGrade,
                          );
                          if (!exists) {
                            final proceed = await _confirmAssignDespiteWarning(
                              dialogContext,
                              "No Grade $checkGrade story exists yet for Set "
                              "$selectedSet. The student will get stuck at "
                              "this step until one is uploaded. Assign "
                              "anyway?",
                            );
                            if (proceed != true) {
                              setDialogState(() => isSubmitting = false);
                              return;
                            }
                          }
                        }

                        try {
                          final response = await http.post(
                            Uri.parse(
                              "$baseUrl/api/classes/${widget.classId}/assessments",
                            ),
                            headers: {
                              ...networkHeaders,
                              'Content-Type': 'application/json',
                              'Accept': 'application/json',
                            },
                            body: jsonEncode({
                              'student_id': studentId,
                              'test_type': selectedTestType,
                              'set_letter': selectedSet,
                              'student_grade': classGrade,
                              if (selectedTestType == 'pre_test')
                                'gst_raw': gstRaw
                              else
                                'start_grade': postTestStartGrade,
                            }),
                          );

                          if ((response.statusCode == 200 ||
                                  response.statusCode == 201) &&
                              mounted) {
                            Navigator.pop(dialogContext);
                            final String label = selectedTestType == 'pre_test'
                                ? 'Pre-Test'
                                : 'Post-Test';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "$label assigned to $studentName!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (studentId == widget.studentId) {
                              _fetchClassDetails();
                            }
                          } else {
                            final decoded = response.body.isNotEmpty
                                ? jsonDecode(response.body)
                                : {};
                            setDialogState(() {
                              isSubmitting = false;
                              errorText =
                                  decoded['message']?.toString() ??
                                  "Could not assign the test (${response.statusCode}).";
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = "Could not reach the server.";
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Assign",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );

    gstController.dispose();
  }

  Future<void> _openAssessment(Map<String, dynamic> a) async {
    final int? studentGrade =
        _toInt(a['student_grade']) ??
        _toInt(
          RegExp(
            r'\d+',
          ).firstMatch(_safeString(_classDetails?['grade_level']))?.group(0),
        );
    if (studentGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Your grade level is missing. Please tell your teacher.",
          ),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    BgmService().stopBgm();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentFlowScreen(
          baseUrl: baseUrl,
          studentId: widget.studentId,
          studentGrade: studentGrade,
          testType: _safeString(a['test_type']),
          setLetter: _safeString(a['set_letter']),
          gstRaw: _toInt(a['gst_raw']),
          directStartGrade: _toInt(a['start_grade']),
        ),
      ),
    );
    if (mounted) _fetchClassDetails();
    BgmService().startBgm();
  }

  Widget _buildAssessmentCard(
    Map<String, dynamic> a,
    SharedPreferences? prefs, {
    required bool locked,
  }) {
    final String status = _assessmentStatus(a, prefs);
    final bool done = _assessmentIsDone(status);

    final String subtitle = locked
        ? "Finish the Pre-Test first"
        : status == 'complete'
        ? "Completed"
        : status == 'not_needed'
        ? "You don't need this one"
        : status == 'in_progress'
        ? "Tap to continue"
        : "Tap to start";

    final IconData trailingIcon = locked
        ? Icons.lock_rounded
        : done
        ? Icons.check_circle_rounded
        : Icons.play_circle_fill_rounded;

    return GestureDetector(
      onTap: () {
        if (locked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Finish all Pre-Test missions first to unlock this! 🔒",
              ),
              backgroundColor: Colors.black87,
            ),
          );
        } else if (done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You already finished this reading test! 🌟"),
              backgroundColor: Colors.black87,
            ),
          );
        } else {
          _openAssessment(a);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: locked ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black, width: 3.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cyanAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 30,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reading Test",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: done ? Colors.green.shade800 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              trailingIcon,
              size: 34,
              color: locked
                  ? Colors.black38
                  : done
                  ? Colors.green.shade700
                  : maroonTheme,
            ),
          ],
        ),
      ),
    );
  }

  void _copyClassCode(String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Secret code '$code' copied to clipboard!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.classCode.isNotEmpty
        ? widget.classCode
        : (_classDetails?['code'] ?? _classDetails?['class_code'] ?? 'N/A');

    Widget mobileLayout = SafeArea(
      child: Column(
        children: [
          // -----------------------------------------
          // Custom Comic-Style Header with X Button
          // -----------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // "X" Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Level
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.className,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_classDetails?['grade_level'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentTheme,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  "Level ${_classDetails!['grade_level']} Zone",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Right Icon Status
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cyanAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          // -----------------------------------------
          // Custom Comic Tabs (Na-update na disenyo)
          // -----------------------------------------
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cyanAccent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: const TabBar(
              indicatorColor: maroonTheme,
              indicatorWeight: 4,
              labelColor: maroonTheme,
              unselectedLabelColor: Colors.black,
              labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_rounded, size: 20),
                      SizedBox(width: 8),
                      Text("Missions"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded, size: 22),
                      SizedBox(width: 8),
                      Text("Heroes"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // -----------------------------------------
          // Tab Content
          // -----------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: maroonTheme),
                  )
                : TabBarView(
                    children: [_buildStoriesTab(), _buildStudentsTab(code)],
                  ),
          ),
        ],
      ),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: ResponsiveLayout(
          mobileLayout: mobileLayout,
          desktopLayout: mobileLayout,
        ),
      ),
    );
  }

  Widget _buildStoriesTab() {
    if (_assignedStories.isEmpty && _assessments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchClassDetails,
        color: maroonTheme,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cyanAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      size: 60,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No missions yet!",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Waiting for the teacher to drop new stories.",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchClassDetails,
      color: maroonTheme,
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          final prefs = snapshot.data;

          // Tag each story with its test_type + completion so search, the
          // filter chips, and the progress summary all agree with what
          // each card badge shows.
          final Set<String> assessedTypes = _assessments
              .map((a) => _safeString(a['test_type']))
              .toSet();

          final List<Map<String, dynamic>> enriched = _assignedStories
              .map((story) {
                final tType = _missionTestType(story);
                final readingDone = _isMissionReadingDone(story, tType, prefs);
                final fullyDone = _isMissionFullyDone(story, tType, prefs);
                return {
                  'story': story,
                  'tType': tType,
                  'readingDone': readingDone,
                  'fullyDone': fullyDone,
                };
              })
              .where((e) => !assessedTypes.contains(e['tType']))
              .toList();

          final int completedCount =
              enriched.where((e) => e['readingDone'] == true).length +
              _assessments
                  .where((a) => _assessmentIsDone(_assessmentStatus(a, prefs)))
                  .length;
          final int totalCount = enriched.length + _assessments.length;

          final List<Map<String, dynamic>> preEntries = enriched
              .where((e) => e['tType'] == 'pre_test')
              .toList();
          final List<Map<String, dynamic>> postEntries = enriched
              .where((e) => e['tType'] == 'post_test')
              .toList();

          // Post-Test stays locked until every Pre-Test mission is fully
          // done. If there are no Pre-Test missions at all, there is
          // nothing to gate on, so Post-Test opens right away.
          final bool preAssessmentsDone = _assessments
              .where((a) => _safeString(a['test_type']) == 'pre_test')
              .every((a) => _assessmentIsDone(_assessmentStatus(a, prefs)));
          final bool allPreTestDone =
              (preEntries.isEmpty ||
                  preEntries.every((e) => e['fullyDone'] == true)) &&
              preAssessmentsDone;

          _maybeCelebratePostTestUnlock(allPreTestDone, prefs);

          bool passesSearchAndFilter(Map<String, dynamic> entry) {
            final story = entry['story'];
            final title = (story['title'] ?? '').toString().toLowerCase();
            if (_missionSearchQuery.isNotEmpty &&
                !title.contains(_missionSearchQuery)) {
              return false;
            }
            if (_missionFilter == 'completed') {
              return entry['readingDone'] == true;
            }
            return true;
          }

          final List<Map<String, dynamic>> filteredPreEntries = preEntries
              .where(passesSearchAndFilter)
              .toList();
          final List<Map<String, dynamic>> filteredPostEntries = postEntries
              .where(passesSearchAndFilter)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                        ],
                      ),
                      child: TextField(
                        controller: _missionSearchController,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search missions...",
                          hintStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.black,
                          ),
                          suffixIcon: _missionSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.black54,
                                  ),
                                  onPressed: () {
                                    _missionSearchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMissionFilterChip('all', 'All'),
                          const SizedBox(width: 8),
                          _buildMissionFilterChip('completed', 'Completed'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress Summary
                    if (totalCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$completedCount of $totalCount missions completed",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: totalCount > 0
                                    ? completedCount / totalCount
                                    : 0,
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  accentTheme,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child:
                    (filteredPreEntries.isEmpty &&
                        filteredPostEntries.isEmpty &&
                        _assessments.isEmpty)
                    ? Center(
                        child: Text(
                          _missionSearchQuery.isNotEmpty ||
                                  _missionFilter != 'all'
                              ? "No missions match your search."
                              : "No missions yet!",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          _buildMissionSection(
                            "📝 PRE-TEST MISSIONS",
                            filteredPreEntries,
                            prefs,
                            locked: false,
                            assessment: _visibleAssessment('pre_test', prefs),
                          ),
                          const SizedBox(height: 28),
                          if (!allPreTestDone)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2.5,
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.lock_rounded,
                                    color: Colors.black54,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Finish all Pre-Test missions to unlock Post-Test!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildMissionSection(
                            "✅ POST-TEST MISSIONS",
                            filteredPostEntries,
                            prefs,
                            locked: !allPreTestDone,
                            assessment: _visibleAssessment('post_test', prefs),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMissionSection(
    String title,
    List<Map<String, dynamic>> entries,
    SharedPreferences? prefs, {
    required bool locked,
    Map<String, dynamic>? assessment,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: locked ? Colors.grey.shade300 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: locked ? Colors.black45 : Colors.black,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock_rounded, size: 16, color: Colors.black45),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (assessment != null)
          _buildAssessmentCard(assessment, prefs, locked: locked)
        else if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: const Center(
              child: Text(
                "No missions here yet.",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildMissionCard(
                entry['story'],
                entry['tType'] as String,
                prefs,
                locked: locked,
              );
            },
          ),
      ],
    );
  }

  Widget _buildMissionCard(
    dynamic story,
    String tType,
    SharedPreferences? prefs, {
    required bool locked,
  }) {
    final pagesCount = (story['pages'] as List?)?.length ?? 0;

    // 🛠️ FIXED COVER URL LOGIC HERE
    String rawCoverPath = _safeString(
      story['cover_image'] ?? story['thumbnail'],
    );
    String coverUrl = "";
    if (rawCoverPath.isNotEmpty) {
      if (rawCoverPath.startsWith('http')) {
        coverUrl = rawCoverPath;
      } else {
        if (rawCoverPath.startsWith('public/')) {
          rawCoverPath = rawCoverPath.replaceFirst('public/', '');
        }
        String cleanBaseUrl = baseUrl.endsWith('/api')
            ? baseUrl.substring(0, baseUrl.length - 4)
            : baseUrl;
        coverUrl = "$cleanBaseUrl/api/get-image?path=$rawCoverPath";
      }
    }

    Widget card = GestureDetector(
      onTap: locked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Finish all Pre-Test missions first to unlock this! 🔒",
                  ),
                  backgroundColor: Colors.black87,
                ),
              );
            }
          : () async {
              BgmService().stopBgm();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return StoryViewerScreen(
                      story: story,
                      baseUrl: baseUrl,
                      studentId: widget.studentId,
                      testType: tType,
                    );
                  },
                ),
              );
              _fetchClassDetails();
              BgmService().startBgm();
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black, width: 3.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                  border: const Border(
                    bottom: BorderSide(color: Colors.black, width: 2.5),
                  ),
                  image: coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                          colorFilter: locked
                              ? ColorFilter.mode(
                                  Colors.white.withOpacity(0.55),
                                  BlendMode.lighten,
                                )
                              : null,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (coverUrl.isEmpty)
                      const Center(
                        child: Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    // Test-type ribbon: a story can be assigned to this class
                    // twice (once as pre_test, once as post_test), which
                    // otherwise look identical — same cover, same title.
                    // Always show which one this tile is before tapping.
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tType == 'pre_test'
                              ? maroonTheme
                              : const Color(0xFF287A7A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          tType == 'pre_test' ? 'PRE-TEST' : 'POST-TEST',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (locked)
                      const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 42,
                          color: Colors.black54,
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final progress = story['student_progress'];
                          final bool isReadingCompleted =
                              progress != null &&
                              (progress['is_reading_completed'] == 1 ||
                                  progress['is_reading_completed'] == true);
                          final bool hasQuizScore =
                              progress != null &&
                              progress['quiz_score'] != null;
                          final bool hasQuiz = story['quiz'] != null;

                          bool isLocallyReadingCompleted =
                              prefs?.getBool(
                                'story_${story['id']}_${tType}_reading_completed',
                              ) ??
                              false;
                          int? localQuizScore = prefs?.getInt(
                            'story_${story['id']}_${tType}_quiz_score',
                          );
                          int? localQuizTotal = prefs?.getInt(
                            'story_${story['id']}_${tType}_quiz_total',
                          );

                          bool readingDone =
                              isReadingCompleted || isLocallyReadingCompleted;
                          bool quizDone =
                              hasQuizScore || localQuizScore != null;

                          String label = "";
                          Color badgeColor = Colors.green;

                          if (quizDone) {
                            final score =
                                localQuizScore ?? progress?['quiz_score'] ?? 0;
                            final total =
                                localQuizTotal ??
                                progress?['total_questions'] ??
                                (story['quiz'] is List
                                    ? (story['quiz'] as List).length
                                    : '?');
                            label = "Quiz Score: $score/$total";
                            badgeColor = cyanAccent;
                          } else if (readingDone) {
                            label = "Read Completed";
                            badgeColor = accentTheme;
                          } else if (hasQuiz) {
                            label = "Contains Quiz";
                            badgeColor = Colors.lightGreenAccent;
                          }

                          if (label.isEmpty) return const SizedBox.shrink();

                          return Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            // Text Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story['title'] ?? 'Untitled Mission',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: locked ? Colors.black45 : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$pagesCount Pages",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: locked ? Colors.black38 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: locked ? Colors.grey.shade400 : maroonTheme,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Icon(
                      locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Locked cards render dimmed and never navigate anywhere -- the
    // onTap above only shows the "finish pre-test first" reminder.
    return locked ? Opacity(opacity: 0.55, child: card) : card;
  }

  Widget _buildMissionFilterChip(String value, String label) {
    final bool selected = _missionFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _missionFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentTheme : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: selected
              ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2))]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab(String code) {
    return RefreshIndicator(
      onRefresh: _fetchClassDetails,
      color: maroonTheme,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Class Code Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 3.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(5, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cyanAccent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Text(
                          "SECRET MISSION CODE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: maroonTheme,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyClassCode(code),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentTheme,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black, width: 2.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text(
                    "Copy",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Fellow Heroes Header
          Row(
            children: [
              const Icon(
                Icons.emoji_people_rounded,
                color: Colors.black,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "FELLOW HEROES (${_filteredStudents.length})",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(3, 3)),
              ],
            ),
            child: TextField(
              controller: _studentSearchController,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: "Search heroes by name...",
                hintStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.black,
                ),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          _studentSearchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_filteredStudents.isEmpty && _studentSearchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 3.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 40,
                    color: Colors.black54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "No heroes match your search.",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else if (_students.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 3.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    size: 40,
                    color: Colors.black54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "No heroes have joined this zone yet.",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._filteredStudents.map((student) {
              final name = student['name'] ?? student['username'] ?? 'Hero';
              final email = student['email'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  onTap: widget.isTeacher
                      ? () => _showAssignAssessmentDialog(student)
                      : null,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentTheme,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: email.isNotEmpty
                      ? Text(
                          email,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: widget.isTeacher
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentTheme,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          onPressed: () => _showAssignAssessmentDialog(student),
                          child: const Text(
                            "Assign Test",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
r