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
  // The real backend supports exactly one linked child per parent
  // (parent_id is a single column on users, not a pivot) — so this is
  // the student's identity, held once...
  int? _studentId;
  String? _studentName;
  // ...and a LIST of classes, since a student can belong to more than
  // one class. The backend used to return only the first class via
  // ->classes()->first(); fixed on the ParentController side to return
  // all of them, and this list is what renders "YOUR CHILD'S CLASSES".
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  // Reading snapshot shown on the dashboard itself (not just after tapping
  // into a class) — latest progress + the words the child is struggling
  // with, pulled from the same endpoints StudentProgressScreen already
  // uses for this student.
  List<dynamic> _progressRecords = [];
  List<dynamic> _mispronunciations = [];
  bool _isLoadingHighlights = false;

  Future<void> _fetchProgressHighlights() async {
    if (_studentId == null) return;
    setState(() => _isLoadingHighlights = true);
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse("${widget.baseUrl}/api/student/$_studentId/all-progress"),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
        http.get(
          Uri.parse(
            "${widget.baseUrl}/api/students/$_studentId/mispronunciations",
          ),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            _progressRecords = jsonDecode(results[0].body)['data'] ?? [];
          }
          if (results[1].statusCode == 200) {
            _mispronunciations = jsonDecode(results[1].body)['data'] ?? [];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching progress highlights: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHighlights = false);
    }
  }

  // Top few words the child has struggled with most, across all stories —
  // same data StudentProgressScreen's "Words" tab charts, just condensed
  // to a handful of chips for the dashboard.
  List<String> get _topStruggleWords {
    final Map<String, int> counts = {};
    for (final m in _mispronunciations) {
      final word = m['word']?.toString();
      if (word == null || word.isEmpty) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  Widget _buildProgressHighlightsCard() {
    if (_isLoadingHighlights) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_progressRecords.isEmpty && _mispronunciations.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = _progressRecords.isNotEmpty ? _progressRecords.last : null;
    final struggleWords = _topStruggleWords;

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
            _studentId = null;
            _studentName = null;
            _classes = [];
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
              _studentId = null;
              _studentName = null;
              _classes = [];
              _isLoading = false;
            });
          }
          return;
        }

        List<dynamic> rawClasses = data['classes'] ?? [];
        // Back-compat: the old response shape put a single class's fields
        // directly on the top-level object instead of in a `classes` array.
        if (rawClasses.isEmpty && data['class_name'] != null) {
          rawClasses = [
            {
              'class_name': data['class_name'],
              'class_code': data['class_code'],
              'grade_level': data['grade_level'],
            },
          ];
        }

        final List<dynamic> rawNotifications = data['notifications'] ?? [];
        final notifications = rawNotifications
            .whereType<Map<String, dynamic>>()
            .toList();

        if (mounted) {
          setState(() {
            _studentId = data['student_id'];
            _studentName = data['student_name'];
            _classes = rawClasses.whereType<Map<String, dynamic>>().toList();
            _notifications = notifications;
            _isLoading = false;
          });
          if (_studentId != null) _fetchProgressHighlights();
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

  @override
  Widget build(BuildContext context) {
    Widget contentBody = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              padding: const EdgeInsets.all(18.0),
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
                      Icons.family_restroom,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Link to Teacher's Class",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Enter the code given by your child's teacher to view their progress.",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
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
                    child: null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
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
            child: const Text(
              "📚 YOUR CHILD'S CLASSES",
              style: TextStyle(
                fontSize: 16,
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
                : _classes.isEmpty
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
                            "Not connected to any class yet!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                      // One-time header showing which child this dashboard
                      // belongs to, since every class card below links to
                      // the SAME student's progress.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.face_rounded,
                              color: maroonTheme,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _studentName ?? 'Your child',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: maroonTheme,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildProgressHighlightsCard(),
                      const SizedBox(height: 14),
                      ..._classes.map((classInfo) {
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
                              onTap: _studentId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentProgressScreen(
                                            studentId: _studentId!,
                                            baseUrl: widget.baseUrl,
                                            studentName:
                                                _studentName ?? 'Student',
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
                                              "Grade ${classInfo['grade_level']}",
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
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "PARENT PORTAL",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (_email != null)
                            Text(
                              _email!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: _buildNotificationBell(),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                          tooltip: "Change Password",
                          onPressed: () {
                            final pid = int.tryParse(widget.parentId) ?? 0;
                            showDialog(
                              context: context,
                              builder: (_) => ChangePasswordDialog(userId: pid),
                            );
                          },
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.exit_to_app_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                          onPressed: _doLogout,
                        ),
                      ),
                    ],
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
