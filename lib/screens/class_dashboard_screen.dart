import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart';
import '../widgets/responsive_layout.dart';
import 'story_view_screen.dart';
import '../services/bgm_service.dart';

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

  final TextEditingController _studentSearchController =
      TextEditingController();
  String _studentSearchQuery = '';

  final TextEditingController _missionSearchController =
      TextEditingController();
  String _missionSearchQuery = '';
  // 'all' | 'pre_test' | 'post_test' | 'completed'
  String _missionFilter = 'all';

  @override
  void initState() {
    super.initState();
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

    if (mounted) setState(() => _isLoading = false);
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
    if (_assignedStories.isEmpty) {
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
          final List<Map<String, dynamic>> enriched = _assignedStories.map((
            story,
          ) {
            final tType = _missionTestType(story);
            final readingDone = _isMissionReadingDone(story, tType, prefs);
            return {'story': story, 'tType': tType, 'readingDone': readingDone};
          }).toList();

          final int completedCount = enriched
              .where((e) => e['readingDone'] == true)
              .length;
          final int totalCount = enriched.length;

          final List<Map<String, dynamic>> filteredEntries = enriched.where((
            entry,
          ) {
            final story = entry['story'];
            final title = (story['title'] ?? '').toString().toLowerCase();
            if (_missionSearchQuery.isNotEmpty &&
                !title.contains(_missionSearchQuery)) {
              return false;
            }
            switch (_missionFilter) {
              case 'pre_test':
                return entry['tType'] == 'pre_test';
              case 'post_test':
                return entry['tType'] == 'post_test';
              case 'completed':
                return entry['readingDone'] == true;
              default:
                return true;
            }
          }).toList();

          final List<dynamic> filteredStories = filteredEntries
              .map((e) => e['story'])
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
                          _buildMissionFilterChip('pre_test', 'Pre-test'),
                          const SizedBox(width: 8),
                          _buildMissionFilterChip('post_test', 'Post-test'),
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
                child: filteredStories.isEmpty
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 350,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: filteredStories.length,
                        itemBuilder: (context, index) {
                          final story = filteredStories[index];
                          final title = story['title'] ?? 'Untitled Mission';
                          final pagesCount =
                              (story['pages'] as List?)?.length ?? 0;
                          String? coverImage =
                              story['cover_image'] ?? story['thumbnail'];

                          // The test_type this story is assigned as in THIS class
                          // (pre_test or post_test) — a story can be assigned as both,
                          // so every local cache key and the reading screen itself must
                          // be scoped to this specific test_type, not just the story id.
                          String tType = "post_test";
                          if (story['pivot'] != null &&
                              story['pivot']['test_type'] != null) {
                            tType = story['pivot']['test_type'];
                          }

                          if (coverImage != null &&
                              coverImage.startsWith('public/')) {
                            coverImage = coverImage.replaceFirst('public/', '');
                          }

                          return GestureDetector(
                            onTap: () async {
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
                                border: Border.all(
                                  color: Colors.black,
                                  width: 3.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(5, 5),
                                  ),
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
                                          bottom: BorderSide(
                                            color: Colors.black,
                                            width: 2.5,
                                          ),
                                        ),
                                        image:
                                            coverImage != null &&
                                                coverImage.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  "$baseUrl/api/get-image?path=$coverImage",
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: Stack(
                                        children: [
                                          if (coverImage == null ||
                                              coverImage.isEmpty)
                                            const Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          // Test-type ribbon: a story can be assigned to
                                          // this class twice (once as pre_test, once as
                                          // post_test), which otherwise look identical —
                                          // same cover, same title. Always show which
                                          // one this tile is, before the student taps it.
                                          Align(
                                            alignment: Alignment.topLeft,
                                            child: Container(
                                              margin: const EdgeInsets.all(8),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: tType == 'pre_test'
                                                    ? maroonTheme
                                                    : const Color(0xFF287A7A),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.black,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Text(
                                                tType == 'pre_test'
                                                    ? 'PRE-TEST'
                                                    : 'POST-TEST',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              final progress =
                                                  story['student_progress'];
                                              final bool isReadingCompleted =
                                                  progress != null &&
                                                  (progress['is_reading_completed'] ==
                                                          1 ||
                                                      progress['is_reading_completed'] ==
                                                          true);
                                              final bool hasQuizScore =
                                                  progress != null &&
                                                  progress['quiz_score'] !=
                                                      null;
                                              final bool hasQuiz =
                                                  story['quiz'] != null;

                                              bool isLocallyReadingCompleted =
                                                  prefs?.getBool(
                                                    'story_${story['id']}_${tType}_reading_completed',
                                                  ) ??
                                                  false;
                                              int?
                                              localQuizScore = prefs?.getInt(
                                                'story_${story['id']}_${tType}_quiz_score',
                                              );
                                              int?
                                              localQuizTotal = prefs?.getInt(
                                                'story_${story['id']}_${tType}_quiz_total',
                                              );

                                              bool readingDone =
                                                  isReadingCompleted ||
                                                  isLocallyReadingCompleted;
                                              bool quizDone =
                                                  hasQuizScore ||
                                                  localQuizScore != null;

                                              String label = "";
                                              Color badgeColor = Colors.green;

                                              if (quizDone) {
                                                final score =
                                                    localQuizScore ??
                                                    progress?['quiz_score'] ??
                                                    0;
                                                final total =
                                                    localQuizTotal ??
                                                    progress?['total_questions'] ??
                                                    (story['quiz'] is List
                                                        ? (story['quiz']
                                                                  as List)
                                                              .length
                                                        : '?');
                                                label =
                                                    "Quiz Score: $score/$total";
                                                badgeColor = cyanAccent;
                                              } else if (readingDone) {
                                                label = "Read Completed";
                                                badgeColor = accentTheme;
                                              } else if (hasQuiz) {
                                                label = "Contains Quiz";
                                                badgeColor =
                                                    Colors.lightGreenAccent;
                                              }

                                              if (label.isEmpty) {
                                                return const SizedBox.shrink();
                                              }

                                              return Align(
                                                alignment: Alignment.topRight,
                                                child: Container(
                                                  margin: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.black,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w900,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "$pagesCount Pages",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: maroonTheme,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
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
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
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
                ),
              );
            }),
        ],
      ),
    );
  }
}
