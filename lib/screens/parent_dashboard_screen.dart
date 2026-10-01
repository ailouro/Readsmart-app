import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/responsive_layout.dart';
import 'login_screen.dart' hide ComicBackground;
import 'student_progress_screen.dart';
import 'student_dashboard.dart'; // To use ComicBackground

class ParentDashboardScreen extends StatefulWidget {
  final String baseUrl;
  final String parentId;

  const ParentDashboardScreen({
    super.key,
    required this.baseUrl,
    required this.parentId,
  });

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final _classCodeController = TextEditingController();
  final _studentLrnController = TextEditingController();

  static const Color maroonTheme = Color(0xFF9B0505);
  static const Color accentTheme = Color(0xFFFDE047);
  static const Color cyanAccent = Color(0xFFAFE1EE);
  static const Color spideyBlue = Color(0xFF1D4ED8);
  static const Color paperColor = Color(0xFFFFF6E4);

  bool _isSubmitting = false;
  // A parent can have several children. Each child has their own id,
  // name and list of classes: [{student_id, student_name, classes: [...]}]
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  // Reading snapshot data, kept PER CHILD (keyed by student id).
  final Map<int, List<dynamic>> _progressByChild = {};
  final Map<int, List<dynamic>> _mispronunciationsByChild = {};
  final Set<int> _loadingHighlights = {};

  Future<void> _fetchProgressHighlights(int studentId) async {
    setState(() => _loadingHighlights.add(studentId));
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse("${widget.baseUrl}/api/student/$studentId/all-progress"),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
        http.get(
          Uri.parse(
            "${widget.baseUrl}/api/students/$studentId/mispronunciations",
          ),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            _progressByChild[studentId] =
                jsonDecode(results[0].body)['data'] ?? [];
          }
          if (results[1].statusCode == 200) {
            _mispronunciationsByChild[studentId] =
                jsonDecode(results[1].body)['data'] ?? [];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching progress highlights for $studentId: $e");
    } finally {
      if (mounted) setState(() => _loadingHighlights.remove(studentId));
    }
  }

  // Top few words this child struggled with most, across all stories.
  List<String> _topStruggleWords(int studentId) {
    final Map<String, int> counts = {};
    for (final m in _mispronunciationsByChild[studentId] ?? const []) {
      final word = m['word']?.toString();
      if (word == null || word.isEmpty) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  // "Grade 5" stays "Grade 5"; a bare "5" becomes "Grade 5".
  String _gradeLabel(dynamic g) {
    final s = g.toString();
    return s.toLowerCase().startsWith('grade') ? s : 'Grade $s';
  }

  Widget _buildProgressHighlightsCard(int studentId) {
    if (_loadingHighlights.contains(studentId)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final progressRecords = _progressByChild[studentId] ?? const [];
    final mispronunciations = _mispronunciationsByChild[studentId] ?? const [];
    if (progressRecords.isEmpty && mispronunciations.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = progressRecords.isNotEmpty ? progressRecords.last : null;
    final struggleWords = _topStruggleWords(studentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
            "Reading Snapshot 📖",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (latest != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    "Level: ${latest['reading_level'] ?? 'N/A'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: cyanAccent,
                ),
                if (latest['oral_fluency_accuracy'] != null)
                  Chip(
                    label: Text(
                      "Accuracy: ${latest['oral_fluency_accuracy']}%",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: accentTheme,
                  ),
              ],
            )
          else
            const Text(
              "No reading activity yet.",
              style: TextStyle(color: Colors.black54),
            ),
          if (struggleWords.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "Words to practice together:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: struggleWords
                  .map(
                    (w) => Chip(
                      label: Text(
                        w,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: maroonTheme,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _doLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: const Text(
          "Log Out 👋",
          style: TextStyle(fontWeight: FontWeight.w900, color: maroonTheme),
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: maroonTheme,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Log Out",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _loadEmail();
  }

  String? _email;

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final String? found =
        prefs.getString('email') ?? prefs.getString('user_email');
    if (mounted && found != null && found.isNotEmpty) {
      setState(() => _email = found);
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.baseUrl}/api/parents/${widget.parentId}/dashboard"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
      );

      // Handle both the fixed backend shape (200, always JSON with a
      // `classes` array) and the old one (404 + null body when no
      // student/class was linked yet), so this works whether or not the
      // ParentController fix has been deployed.
      if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _children = [];
            _isLoading = false;
          });
        }
        return;
      }

      if (response.statusCode == 200) {
        final dynamic data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;

        if (data == null || data is! Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _children = [];
              _isLoading = false;
            });
          }
          return;
        }

        // New shape: data['children'] = [{student_id, student_name, classes}].
        List<dynamic> rawChildren = data['children'] ?? [];
        // Back-compat: old single-child shape.
        if (rawChildren.isEmpty && data['student_id'] != null) {
          List<dynamic> oldClasses = data['classes'] ?? [];
          if (oldClasses.isEmpty && data['class_name'] != null) {
            oldClasses = [
              {
                'class_name': data['class_name'],
                'class_code': data['class_code'],
                'grade_level': data['grade_level'],
              },
            ];
          }
          rawChildren = [
            {
              'student_id': data['student_id'],
              'student_name': data['student_name'],
              'classes': oldClasses,
            },
          ];
        }
        final children = rawChildren
            .whereType<Map<String, dynamic>>()
            .map((c) => <String, dynamic>{
                  ...c,
                  'classes':
                      (c['classes'] as List<dynamic>? ?? const [])
                          .whereType<Map<String, dynamic>>()
                          .toList(),
                })
            .toList();

        final List<dynamic> rawNotifications = data['notifications'] ?? [];
        final notifications = rawNotifications
            .whereType<Map<String, dynamic>>()
            .toList();

        if (mounted) {
          setState(() {
            _children = children;
            _notifications = notifications;
            _isLoading = false;
          });
          for (final c in children) {
            final id = int.tryParse(c['student_id'].toString());
            if (id != null) _fetchProgressHighlights(id);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching parent dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Opens the notification list when the bell icon is tapped. Each item
  // has its own "Got it" button — dismissing one marks it seen on the
  // backend and removes it from the badge count locally, without closing
  // the whole list if there are others left.
  Future<void> _openNotificationsSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (_notifications.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No new notifications 🎉",
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Notifications 🔔",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: maroonTheme,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._notifications.map((n) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.celebration,
                          color: maroonTheme,
                        ),
                        title: Text(
                          n['message']?.toString() ?? "Update available",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: (n['lrn'] != null || n['password'] != null)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (n['lrn'] != null)
                                      Text("Username (LRN): ${n['lrn']}"),
                                    if (n['password'] != null)
                                      Text("Password: ${n['password']}"),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Please change the password after first login.",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                        isThreeLine: n['lrn'] != null || n['password'] != null,
                        trailing: TextButton(
                          onPressed: () async {
                            final id = n['id'];
                            if (id != null) await _dismissNotification(id);
                            setState(() => _notifications.remove(n));
                            setSheetState(() {});
                            if (_notifications.isEmpty && mounted) {
                              Navigator.pop(ctx);
                              _fetchDashboard(); // refresh classes/child info
                            }
                          },
                          child: const Text(
                            "Got it",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: maroonTheme,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // A bell icon with a small red dot badge when there are unread
  // notifications — tap opens the list via _openNotificationsSheet.
  Widget _buildNotificationBell({double size = 20}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_rounded,
            color: Colors.black,
            size: size,
          ),
          onPressed: _openNotificationsSheet,
        ),
        if (_notifications.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _dismissNotification(dynamic id) async {
    try {
      await http.post(
        Uri.parse("${widget.baseUrl}/api/parents/notifications/$id/dismiss"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
      );
    } catch (e) {
      debugPrint("Error dismissing notification $id: $e");
    }
  }

  Future<void> _enrollStudent() async {
    final code = _classCodeController.text.trim();
    final lrn = _studentLrnController.text.trim();

    if (code.isEmpty || lrn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse("${widget.baseUrl}/api/parents/enroll");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "parent_id": widget.parentId,
          "class_code": code,
          "lrn": lrn,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // The class doesn't attach immediately anymore — the teacher has
        // to approve the request first — so this just re-syncs whatever
        // did or didn't change (e.g. an "already enrolled" response still
        // returns 200 with nothing new to show).
        await _fetchDashboard();

        // Use whatever message the backend sent (it varies: "request
        // sent", "already enrolled", "already pending") instead of a
        // single hardcoded success line.
        String message = "✅ Request sent! Waiting for the teacher's approval.";
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) message = data['message'];
        } catch (_) {}

        if (mounted) {
          _classCodeController.clear();
          _studentLrnController.clear();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        }
      } else {
        String errorMsg = "Invalid Class Code or Student Info";
        try {
          final errData = jsonDecode(response.body);
          if (errData['message'] != null) errorMsg = errData['message'];
        } catch (_) {
          errorMsg = response.body.isEmpty
              ? "Server Error \${response.statusCode}"
              : response.body;
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Enrollment Failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showEnrollDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 3.5),
          ),
          title: const Text(
            "Request to Join Class",
            style: TextStyle(color: maroonTheme, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _studentLrnController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Child's LRN",
                  helperText: "The 12-digit LRN on your child's report card",
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 2.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: maroonTheme, width: 3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _classCodeController,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Class Code from Teacher",
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 2.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: maroonTheme, width: 3),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentTheme,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
              onPressed: _isSubmitting ? null : _enrollStudent,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Send Request",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? accentTheme : Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(
    Map<String, dynamic> classInfo,
    int? studentId,
    String studentName,
  ) {
    return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black, width: 3.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(5, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: studentId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentProgressScreen(
                                            studentId: studentId,
                                            baseUrl: widget.baseUrl,
                                            studentName:
                                                studentName,
                                          ),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cyanAccent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            classInfo['class_name'] ?? 'Class',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              color: Colors.black,
                                            ),
                                          ),
                                          if (classInfo['grade_level'] !=
                                              null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _gradeLabel(classInfo['grade_level']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              "Code: ${classInfo['class_code'] ?? '—'}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentTheme,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: const Text(
                                        "VIEW PROGRESS",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
  }

  // One block per child: name header, reading snapshot, then their classes.
  List<Widget> _buildChildSection(Map<String, dynamic> child) {
    final int? studentId = int.tryParse(child['student_id'].toString());
    final String studentName = (child['student_name'] ?? 'Your child').toString();
    final List<Map<String, dynamic>> classes =
        (child['classes'] as List<Map<String, dynamic>>? ?? const []);

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4, top: 4),
        child: Row(
          children: [
            const Icon(Icons.face_rounded, color: maroonTheme, size: 20),
            const SizedBox(width: 8),
            Text(
              studentName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: maroonTheme,
              ),
            ),
          ],
        ),
      ),
      if (studentId != null) _buildProgressHighlightsCard(studentId),
      const SizedBox(height: 6),
      if (classes.isEmpty)
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            "Not in a class yet — tap JOIN above with this child's LRN and class code.",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ...classes.map((c) => _buildClassCard(c, studentId, studentName)),
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isPhone = MediaQuery.of(context).size.width < 600;
    Widget contentBody = Padding(
      padding: EdgeInsets.all(isPhone ? 14.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. WELCOME CARD & JOIN CLASS BUTTON
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 3.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(5, 5)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 14.0 : 18.0),
              child: Builder(
                builder: (context) {
                  final iconBadge = Container(
                    padding: EdgeInsets.all(isPhone ? 10 : 12),
                    decoration: BoxDecoration(
                      color: cyanAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    child: Icon(
                      Icons.family_restroom,
                      color: Colors.black,
                      size: isPhone ? 28 : 36,
                    ),
                  );
                  final texts = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Link to Teacher's Class",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: isPhone ? 16 : 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Enter the code given by your child's teacher to view their progress.",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: isPhone ? 12 : 13,
                        ),
                      ),
                    ],
                  );
                  final joinButton = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentTheme,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.black, width: 2.5),
                      ),
                    ),
                    onPressed: _showEnrollDialog,
                    child: const Text(
                      "JOIN",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );

                  if (isPhone) {
                    // Phone: icon + text on top, full-width JOIN below,
                    // so nothing gets squeezed into a narrow column.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            iconBadge,
                            const SizedBox(width: 12),
                            Expanded(child: texts),
                          ],
                        ),
                        const SizedBox(height: 12),
                        joinButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      iconBadge,
                      const SizedBox(width: 16),
                      Expanded(child: texts),
                      const SizedBox(width: 10),
                      joinButton,
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isPhone ? 18 : 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accentTheme,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(3, 3)),
              ],
            ),
            child: Text(
              "📚 YOUR CHILD'S CLASSES",
              style: TextStyle(
                fontSize: isPhone ? 14 : 16,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: maroonTheme),
                  )
                : _children.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black, width: 3.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(5, 5)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cyanAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              size: 50,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No child linked yet!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Please ask the school admin to link your child's account.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                      right: 6,
                      left: 6,
                      top: 2,
                    ),
                    children: [
                      ..._children.expand((c) => _buildChildSection(c)),
                    ],
                  ),
          ),
        ],
      ),
    );

    // Small round icon button used in the phone app bar. Compact on
    // purpose: the old 48px IconButtons + margins pushed the logout
    // button off the right edge on narrow phones.
    Widget appBarIcon(Widget icon, VoidCallback? onTap, {String? tooltip}) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
          ],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: tooltip,
          icon: icon,
          onPressed: onTap,
        ),
      );
    }

    Widget mobileLayout = Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: maroonTheme,
            border: Border(bottom: BorderSide(color: Colors.black, width: 3.5)),
            boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 4))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.family_restroom,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  // Expanded + ellipsis so the title/email shrink instead of
                  // pushing the action buttons off screen.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "PARENT PORTAL",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (_email != null)
                          Text(
                            _email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      appBarIcon(
                        const Icon(
                          Icons.notifications_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        _openNotificationsSheet,
                        tooltip: "Notifications",
                      ),
                      if (_notifications.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  appBarIcon(
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    () {
                      final pid = int.tryParse(widget.parentId) ?? 0;
                      showDialog(
                        context: context,
                        builder: (_) => ChangePasswordDialog(userId: pid),
                      );
                    },
                    tooltip: "Change Password",
                  ),
                  const SizedBox(width: 8),
                  appBarIcon(
                    const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    _doLogout,
                    tooltip: "Log Out",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ComicBackground(child: contentBody),
    );

    Widget desktopLayout = Scaffold(
      backgroundColor: paperColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          Container(
            width: 260,
            color: maroonTheme,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Icon(
                      Icons.family_restroom,
                      color: maroonTheme,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "PARENT PORTAL",
                        style: TextStyle(
                          color: accentTheme,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _buildNotificationBell(size: 16),
                      ),
                    ],
                  ),
                  if (_email != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _email!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(color: Colors.white24, thickness: 1.2),
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(Icons.dashboard_rounded, "Dashboard", () {}),
                  _buildNavItem(
                    Icons.add_link_rounded,
                    "Join Class",
                    _showEnrollDialog,
                  ),
                  _buildNavItem(
                    Icons.lock_reset_rounded,
                    "Change Password",
                    () {
                      final pid = int.tryParse(widget.parentId) ?? 0;
                      showDialog(
                        context: context,
                        builder: (_) => ChangePasswordDialog(userId: pid),
                      );
                    },
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(color: Colors.white24, thickness: 1.2),
                  ),
                  _buildNavItem(
                    Icons.logout_rounded,
                    "Log Out",
                    _doLogout,
                    danger: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Main Content Area
          Expanded(
            child: ClipRect(
              child: ComicBackground(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: contentBody,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;
        return isDesktop ? desktopLayout : mobileLayout;
      },
    );
  }
}