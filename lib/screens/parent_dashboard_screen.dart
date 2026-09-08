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
  final _studentNameController = TextEditingController();

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
  bool _isLoading = true;

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

        if (mounted) {
          setState(() {
            _studentId = data['student_id'];
            _studentName = data['student_name'];
            _classes = rawClasses.whereType<Map<String, dynamic>>().toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching parent dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enrollStudent() async {
    final code = _classCodeController.text.trim();
    final name = _studentNameController.text.trim();

    if (code.isEmpty || name.isEmpty) {
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
          "student_name": name,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Re-fetch the full list from the server instead of overwriting
        // local state with just this one response — that's what was
        // silently dropping previously-enrolled children before.
        await _fetchDashboard();

        if (mounted) {
          _classCodeController.clear();
          _studentNameController.clear();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Successfully enrolled in Class!"),
              backgroundColor: Colors.green,
            ),
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
            "Enroll Child in Class",
            style: TextStyle(color: maroonTheme, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _studentNameController,
                decoration: InputDecoration(
                  labelText: "Child's Full Name",
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
                      "Join Class",
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
                    child: const Text(
                      "JOIN",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
                          const Text(
                            "Click 'Join' above to enroll your child.",
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
                  const Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "PARENT PORTAL",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
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
                  const Text(
                    "PARENT PORTAL",
                    style: TextStyle(
                      color: accentTheme,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 14,
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
