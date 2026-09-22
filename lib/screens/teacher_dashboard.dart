import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theapp/screens/story_view_screen.dart';
import 'package:theapp/screens/upload_story_screen.dart';
import 'package:theapp/screens/story_editor_screen.dart';
import '../services/config.dart';
import '../services/phil_iri_rules.dart';
import '../services/phil_iri_session.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/bouncy_tap.dart';
import 'teacher_profile_screen.dart';
import 'teacher_analytics_dashboard.dart';
import 'login_screen.dart';

String _safeString(dynamic value, [String fallback = ""]) {
  if (value == null) return fallback;
  final String str = value.toString();
  if (str == "null" || str == "undefined") return fallback;
  return str;
}

class TeacherDashboard extends StatefulWidget {
  final String userName;
  final dynamic teacherId;

  const TeacherDashboard({super.key, required this.userName, this.teacherId});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _doLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: const Text(
          "Log Out 👋",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF940D0D),
          ),
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
              backgroundColor: const Color(0xFF940D0D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
  Widget build(BuildContext context) {
    Widget mobileLayout = Scaffold(
      backgroundColor: const Color(0xFFD4B2C2),
      body: SafeArea(
        child: Column(
          children: [
            _TopHeaderBar(
              userName: widget.userName,
              teacherId: widget.teacherId,
              onLogout: _doLogout,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _LibraryTab(
                    userName: widget.userName,
                    teacherId: widget.teacherId,
                  ),
                  _StudentsTab(teacherId: widget.teacherId),
                  _AlertsTab(teacherId: widget.teacherId),
                  TeacherProfileScreen(userName: widget.userName),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFF940D0D),
          unselectedItemColor: Colors.black54,
          backgroundColor: Colors.white,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.collections_bookmark),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );

    Widget desktopLayout = Scaffold(
      backgroundColor: const Color(0xFFD4B2C2),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Color(0xFF940D0D),
              border: Border(right: BorderSide(color: Colors.black, width: 4)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // SVES LOGO
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/sves_logo.jpg',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'READSMART HUB',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFDE047),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildDesktopNavItem(
                  icon: Icons.collections_bookmark,
                  label: 'Library',
                  isActive: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                const SizedBox(height: 16),
                _buildDesktopNavItem(
                  icon: Icons.people_alt,
                  label: 'Students',
                  isActive: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _buildDesktopNavItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alerts',
                  isActive: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                const SizedBox(height: 16),
                _buildDesktopNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  isActive: _selectedIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
                const Spacer(),
                _buildDesktopNavItem(
                  icon: Icons.logout,
                  label: 'Log Out',
                  isActive: false,
                  onTap: _doLogout,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  _LibraryTab(
                    userName: widget.userName,
                    teacherId: widget.teacherId,
                  ),
                  _StudentsTab(teacherId: widget.teacherId),
                  _AlertsTab(teacherId: widget.teacherId),
                  TeacherProfileScreen(userName: widget.userName),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return ResponsiveLayout(
      mobileLayout: mobileLayout,
      desktopLayout: desktopLayout,
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: Colors.black, width: 3) : null,
            boxShadow: isActive
                ? const [BoxShadow(color: Colors.black, offset: Offset(4, 4))]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.black : Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isActive ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TOP HEADER BAR
class _TopHeaderBar extends StatefulWidget {
  final String userName;
  final dynamic teacherId;
  final VoidCallback onLogout;

  const _TopHeaderBar({
    required this.userName,
    this.teacherId,
    required this.onLogout,
  });

  @override
  State<_TopHeaderBar> createState() => _TopHeaderBarState();
}

class _TopHeaderBarState extends State<_TopHeaderBar> {
  List<Map<String, dynamic>> _classRequests = [];
  bool _isLoadingRequests = false;

  static const Color maroonTheme = Color(0xFF940D0D);
  static const Color paperColor = Color(0xFFFFF6E4);

  @override
  void initState() {
    super.initState();
    _fetchClassRequests();
  }

  int get _teacherIdInt {
    if (widget.teacherId != null && widget.teacherId.toString() != "null") {
      return int.tryParse(widget.teacherId.toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _fetchClassRequests() async {
    final tId = _teacherIdInt;
    if (tId == 0) return;

    setState(() => _isLoadingRequests = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/teachers/$tId/class-requests"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _classRequests = raw.whereType<Map<String, dynamic>>().toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching class requests: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _respondToRequest(dynamic id, bool approve) async {
    try {
      final action = approve ? 'approve' : 'decline';
      final response = await http.post(
        Uri.parse("$baseUrl/api/teachers/class-requests/$id/$action"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _classRequests.removeWhere((r) => r['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                approve ? "Request approved ✅" : "Request declined",
              ),
              backgroundColor: approve ? Colors.green : Colors.grey[700],
            ),
          );
        }
      } else {
        throw Exception("Server responded with ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to respond: $e")));
      }
    }
  }

  void _openRequestsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (_classRequests.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No pending class requests 🎉",
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
                    "Class Join Requests 🔔",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: maroonTheme,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._classRequests.map((req) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.person_add_alt_1,
                          color: maroonTheme,
                        ),
                        title: Text(
                          req['student_name']?.toString() ?? "A student",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          "wants to join ${req['class_name'] ?? 'a class'}"
                          "\nrequested by ${req['parent_name'] ?? 'a parent'}",
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: "Approve",
                              onPressed: () async {
                                final id = req['id'];
                                await _respondToRequest(id, true);
                                setSheetState(() {});
                                if (_classRequests.isEmpty && mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.redAccent,
                              ),
                              tooltip: "Decline",
                              onPressed: () async {
                                final id = req['id'];
                                await _respondToRequest(id, false);
                                setSheetState(() {});
                                if (_classRequests.isEmpty && mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                          ],
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

  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2.5),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.notifications_rounded,
              color: Colors.black,
              size: 20,
            ),
            onPressed: _openRequestsSheet,
          ),
        ),
        if (_classRequests.isNotEmpty)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_classRequests.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF940D0D),
        border: Border(bottom: BorderSide(color: Colors.black, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/sves_logo.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "READSMART HUB",
                  style: TextStyle(
                    color: Color(0xFFFDE047),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  widget.userName.isNotEmpty ? widget.userName : "Teacher",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildNotificationBell(),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.black, size: 20),
              onPressed: widget.onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

// COMIC BACKGROUND & WRAPPER
class ComicBackgroundWrapper extends StatefulWidget {
  final Widget child;
  const ComicBackgroundWrapper({super.key, required this.child});

  @override
  State<ComicBackgroundWrapper> createState() => _ComicBackgroundWrapperState();
}

class _ComicBackgroundWrapperState extends State<ComicBackgroundWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _SunburstPainter(
                  rotation: _controller.value * 2 * math.pi,
                ),
              );
            },
          ),
        ),
        const Positioned(
          top: -20,
          left: -40,
          child: _ComicCloud(width: 180, height: 90),
        ),
        const Positioned(
          top: -10,
          right: -30,
          child: _ComicCloud(width: 160, height: 80),
        ),
        const Positioned(
          top: 320,
          right: -50,
          child: _ComicCloud(width: 190, height: 90),
        ),
        const Positioned(
          bottom: -30,
          left: -40,
          child: _ComicCloud(width: 200, height: 100),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _SunburstPainter extends CustomPainter {
  final double rotation;
  _SunburstPainter({this.rotation = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = math.max(size.width, size.height) * 1.5;
    final paint1 = Paint()..color = const Color(0xFFD4B2C2);
    final paint2 = Paint()..color = const Color(0xFFE4C7D5);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    const int numberOfRays = 24;
    final double angleStep = (2 * math.pi) / numberOfRays;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (int i = 0; i < numberOfRays; i += 2) {
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        i * angleStep,
        angleStep,
        false,
      );
      path.close();
      canvas.drawPath(path, paint2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

class _ComicCloud extends StatelessWidget {
  final double width;
  final double height;
  const _ComicCloud({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFC7EEFF),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.black, width: 3.5),
      ),
    );
  }
}

// COMIC BADGE HEADER
class ComicBadgeHeader extends StatelessWidget {
  final String title;
  const ComicBadgeHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4)),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(12, -2),
          child: ClipPath(
            clipper: _PointerClipper(),
            child: Container(width: 16, height: 12, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _PointerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// TAB 1: LIBRARY TAB
class _LibraryTab extends StatefulWidget {
  final String userName;
  final dynamic teacherId;
  const _LibraryTab({required this.userName, this.teacherId});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  static const Color maroonTheme = Color(0xFF940D0D);
  static const Color accentTheme = Color(0xFFFDE047);
  List<Map<String, dynamic>> _stories = [];
  bool _isLoading = true;
  String _storySearchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchStories();
  }

  Future fetchStories() async {
    try {
      setState(() => _isLoading = true);
      final response = await http.get(
        Uri.parse("$baseUrl/api/stories"),
        headers: networkHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> rawList = decoded is List ? decoded : [];
        final List<Map<String, dynamic>> cleanList = [];
        for (var item in rawList) {
          if (item is Map) {
            cleanList.add(Map<String, dynamic>.from(item));
          }
        }
        setState(() {
          _stories = cleanList;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching stories: $e"),
            backgroundColor: Color(0xFFFC9272),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStory(dynamic storyId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Story"),
        content: const Text("Are you sure you want to delete this story?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: maroonTheme),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/api/stories/$storyId"),
        headers: networkHeaders,
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Story deleted successfully."),
            backgroundColor: Color(0xFF8BCA84),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );

        fetchStories();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete story. Status code: ${res.statusCode}",
            ),
            backgroundColor: Color(0xFFFC9272),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting story: $e"),
          backgroundColor: Color(0xFFFC9272),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ComicBackgroundWrapper(
      child: RefreshIndicator(
        onRefresh: fetchStories,
        color: maroonTheme,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBAE6FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.collections_bookmark_rounded,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
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
                            child: const Text(
                              "TEACHER DASHBOARD",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ready to Teach, ${widget.userName}?",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                  color: accentTheme,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UploadStoryScreen(),
                        ),
                      );
                      if (result == true) fetchStories();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Create New Story",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "Upload a new lesson or storybook",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
                child: TextField(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search stories by title...",
                    hintStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    suffixIcon: _storySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.black54,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _storySearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _storySearchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildLibrarySection(
                title: "📝 PRE-TEST STORIES",
                stories: _stories
                    .where(
                      (s) =>
                          _safeString(s['story_type'], 'pre_test') !=
                          'post_test',
                    )
                    .where(
                      (s) => _safeString(
                        s['title'],
                      ).toLowerCase().contains(_storySearchQuery),
                    )
                    .toList(),
                emptyMessage: _storySearchQuery.isEmpty
                    ? "No pre-test stories published yet."
                    : "No pre-test stories match \"$_storySearchQuery\".",
              ),
              const SizedBox(height: 30),
              _buildLibrarySection(
                title: "✅ POST-TEST STORIES",
                stories: _stories
                    .where((s) => _safeString(s['story_type']) == 'post_test')
                    .where(
                      (s) => _safeString(
                        s['title'],
                      ).toLowerCase().contains(_storySearchQuery),
                    )
                    .toList(),
                emptyMessage: _storySearchQuery.isEmpty
                    ? "No post-test stories published yet."
                    : "No post-test stories match \"$_storySearchQuery\".",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrarySection({
    required String title,
    required List<Map<String, dynamic>> stories,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComicBadgeHeader(title: title),
        const SizedBox(height: 10),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(50.0),
              child: CircularProgressIndicator(color: maroonTheme),
            ),
          )
        else if (stories.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_stories,
                    size: 70,
                    color: Colors.black54,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildGradeSplitGrid(stories),
      ],
    );
  }

  // Phil-IRI graded passages exist for Grade 2 through Grade 7, so the
  // library groups stories the same way -- one full-width section per
  // grade that actually has stories, in order. Ang mga kwentong wala pang
  // itinakdang grade level ay ipinapakita sa isang hiwalay na seksyon sa
  // ibaba, para walang kwentong nawawala sa view habang naghihintay pa ng
  // grade assignment mula sa guro.
  static const List<String> _libraryGrades = [
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
  ];
  static const List<String> _libraryGradeEmojis = [
    '🟦',
    '🟪',
    '🟧',
    '🟩',
    '🟨',
    '🟥',
  ];

  Widget _buildGradeSplitGrid(List<Map<String, dynamic>> stories) {
    final List<Widget> sections = [];
    for (int i = 0; i < _libraryGrades.length; i++) {
      final String grade = _libraryGrades[i];
      final List<Map<String, dynamic>> matching = stories
          .where((s) => _safeString(s['grade_level']) == grade)
          .toList();
      if (matching.isEmpty) continue;
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 24));
      sections.add(
        _buildGradeColumn(
          "${_libraryGradeEmojis[i]} ${grade.toUpperCase()}",
          matching,
          fullWidth: true,
        ),
      );
    }

    final List<Map<String, dynamic>> unassigned = stories
        .where((s) => _safeString(s['grade_level']).isEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections,
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildGradeColumn(
            "❔ NO GRADE LEVEL YET",
            unassigned,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildGradeColumn(
    String label,
    List<Map<String, dynamic>> stories, {
    bool fullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (stories.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black26, width: 2),
            ),
            child: const Text(
              "Wala pang kwento dito.",
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stories.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: fullWidth ? 350 : 230,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              return _buildStoryCard(stories[index]);
            },
          ),
      ],
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> story) {
    List pages = story['pages'] is List ? story['pages'] : [];

    // 🛠️ FIXED COVER URL LOGIC HERE
    String rawCoverPath = _safeString(story['cover_image']);
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

    final String gradeLabel = _safeString(story['grade_level']);
    final String setLabel = _safeString(story['set_letter']);

    return Stack(
      children: [
        BouncyTap(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    StoryViewerScreen(story: story, baseUrl: baseUrl),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 3.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    child: coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            headers: const {
                              "ngrok-skip-browser-warning": "69420",
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: accentTheme,
                              child: const Icon(
                                Icons.image,
                                color: Colors.black87,
                                size: 35,
                              ),
                            ),
                          )
                        : Container(
                            color: accentTheme,
                            child: const Icon(
                              Icons.image,
                              color: Colors.black87,
                              size: 35,
                            ),
                          ),
                  ),
                ),
                const Divider(color: Colors.black, thickness: 3, height: 3),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _safeString(story['title'], 'Untitled'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "${pages.length} Pages",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 5,
          left: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (story['quiz'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF8BCA84),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Text(
                    "With Quiz",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              if (story['quiz'] != null && gradeLabel.isNotEmpty)
                const SizedBox(height: 4),
              if (gradeLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF940D0D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    gradeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              if (gradeLabel.isNotEmpty && setLabel.isNotEmpty)
                const SizedBox(height: 4),
              if (setLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    setLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoryEditorScreen(story: story, baseUrl: baseUrl),
                    ),
                  ).then((_) {
                    fetchStories();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _deleteStory(story['id'] ?? story['_id']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// TAB 2: STUDENTS TAB
class _StudentsTab extends StatefulWidget {
  final dynamic teacherId;
  const _StudentsTab({this.teacherId});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  static const Color maroonTheme = Color(0xFF940D0D);
  static const Color accentTheme = Color(0xFFFDE047);
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  bool _isLoadingAnalytics = true;
  Map<String, dynamic> _summaryData = {};
  List<dynamic> _mispronunciations = [];
  String _studentSearchQuery = '';

  final Map<dynamic, Future<List<dynamic>>> _progressFutureCache = {};

  Future<List<dynamic>> _fetchStudentProgress(dynamic studentId) {
    if (studentId == null) return Future.value(const []);
    return _progressFutureCache.putIfAbsent(studentId, () async {
      try {
        final res = await http.get(
          Uri.parse("$baseUrl/api/student/$studentId/all-progress"),
          headers: networkHeaders,
        );
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          return (decoded['data'] ?? []) as List<dynamic>;
        }
      } catch (e) {
        debugPrint("Error fetching student progress: $e");
      }
      return const [];
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _fetchAnalytics();
  }

  Future _fetchAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      int tId = 0;
      if (widget.teacherId != null && widget.teacherId.toString() != "null") {
        tId = int.tryParse(widget.teacherId.toString()) ?? 0;
      }
      if (tId == 0) {
        final prefs = await SharedPreferences.getInstance();
        tId =
            prefs.getInt('user_id') ??
            prefs.getInt('id') ??
            prefs.getInt('teacher_id') ??
            1;
      }

      final summaryRes = await http.get(
        Uri.parse("$baseUrl/api/teachers/$tId/dashboard-summary"),
        headers: networkHeaders,
      );
      final mispronunciationRes = await http.get(
        Uri.parse("$baseUrl/api/teachers/$tId/mispronunciations"),
        headers: networkHeaders,
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
          _isLoadingAnalytics = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingAnalytics = false);
      }
    } catch (e) {
      debugPrint("Error loading analytics: $e");
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  Future _fetchClasses() async {
    try {
      setState(() => _isLoading = true);

      int tId = 0;
      if (widget.teacherId != null && widget.teacherId.toString() != "null") {
        tId = int.tryParse(widget.teacherId.toString()) ?? 0;
      }
      if (tId == 0) {
        final prefs = await SharedPreferences.getInstance();
        tId =
            prefs.getInt('user_id') ??
            prefs.getInt('id') ??
            prefs.getInt('teacher_id') ??
            1;
      }

      final response = await http.get(
        Uri.parse("$baseUrl/api/teachers/$tId/classes"),
        headers: networkHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        final dynamic decoded = jsonDecode(response.body);

        List<dynamic> rawList = [];

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          rawList = decoded['classes'] ?? decoded['data'] ?? [];
        }

        final List<Map<String, dynamic>> cleanList = [];
        for (var item in rawList) {
          if (item is Map) {
            cleanList.add(Map<String, dynamic>.from(item));
          }
        }

        setState(() {
          _classes = cleanList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openClassDetails(
    BuildContext context,
    Map<String, dynamic> item,
    String className,
    String grade,
    String section,
  ) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassDetailsSheet(
        item: item,
        className: className,
        grade: grade,
        section: section,
        buildRecordCard: _buildLearnerRecordCard,
      ),
    );

    if (result == true) {
      _fetchClasses();
    }
  }

  void _showAddStudentDialog() {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final lrnCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    String selectedGrade = 'Grade 5';
    bool isCreating = false;
    String? lrnError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 3.5),
          ),
          backgroundColor: const Color(0xFFFDE047),
          title: const Text(
            "ADD STUDENT 🎒",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "First Name",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Last Name",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lrnCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "LRN (used as login)",
                    errorText: lrnError,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGrade,
                  decoration: InputDecoration(
                    labelText: "Grade Level",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      const [
                            'Grade 2',
                            'Grade 3',
                            'Grade 4',
                            'Grade 5',
                            'Grade 6',
                            'Grade 7',
                          ]
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedGrade = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Section",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF940D0D),
              ),
              onPressed: isCreating
                  ? null
                  : () async {
                      setDialogState(() => lrnError = null);

                      if (firstNameCtrl.text.trim().isEmpty ||
                          lastNameCtrl.text.trim().isEmpty ||
                          lrnCtrl.text.trim().isEmpty ||
                          sectionCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Please fill in all fields!"),
                            backgroundColor: const Color(0xFFFFB347),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            margin: const EdgeInsets.only(
                              bottom: 24,
                              left: 16,
                              right: 16,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        final response = await http.post(
                          Uri.parse("$baseUrl/api/admin/students"),
                          headers: {
                            ...networkHeaders,
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                          },
                          body: jsonEncode({
                            'first_name': firstNameCtrl.text.trim(),
                            'last_name': lastNameCtrl.text.trim(),
                            'lrn': lrnCtrl.text.trim(),
                            'grade_level': selectedGrade,
                            'section': sectionCtrl.text.trim(),
                          }),
                        );

                        final decoded = response.body.isNotEmpty
                            ? jsonDecode(response.body)
                            : {};

                        if ((response.statusCode == 200 ||
                                response.statusCode == 201) &&
                            mounted) {
                          Navigator.pop(context);
                          showDialog(
                            context: this.context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 3.5,
                                ),
                              ),
                              title: const Text("Student Added! 🎉"),
                              content: Text(
                                "LRN (login): ${lrnCtrl.text.trim()}\n"
                                "Default password: readsmart123\n\n"
                                "Please share these with the student securely.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Done"),
                                ),
                              ],
                            ),
                          );
                          _fetchAnalytics();
                        } else if (response.statusCode == 422) {
                          final errors = (decoded['errors'] as Map?) ?? {};
                          final lrnMsg = (errors['lrn'] as List?)?.first;
                          setDialogState(() {
                            isCreating = false;
                            lrnError =
                                lrnMsg?.toString() ??
                                (decoded['message']?.toString());
                          });
                        } else {
                          setDialogState(() => isCreating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                decoded['message']?.toString() ??
                                    "Could not create student.",
                              ),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              margin: const EdgeInsets.only(
                                bottom: 24,
                                left: 16,
                                right: 16,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Could not reach the server. Please try again.",
                            ),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            margin: const EdgeInsets.only(
                              bottom: 24,
                              left: 16,
                              right: 16,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Create",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateClassDialog() {
    final nameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    String selectedGrade = 'Grade 5';
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 3.5),
          ),
          backgroundColor: const Color(0xFFFDE047),
          title: const Text(
            "CREATE NEW CLASS 🏫",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Class Name (e.g. Reading Intervention)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGrade,
                  decoration: InputDecoration(
                    labelText: "Grade Level",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      const [
                            'Grade 2',
                            'Grade 3',
                            'Grade 4',
                            'Grade 5',
                            'Grade 6',
                            'Grade 7',
                          ]
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedGrade = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: InputDecoration(
                    labelText: "Section (Optional)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF940D0D),
              ),
              onPressed: isCreating
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Class Name is required!"),
                            backgroundColor: Color(0xFFFFB347),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            margin: const EdgeInsets.only(
                              bottom: 24,
                              left: 16,
                              right: 16,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      String finalSection = sectionCtrl.text.trim();
                      if (finalSection.isEmpty) finalSection = "N/A";

                      int tId = 0;
                      if (widget.teacherId != null &&
                          widget.teacherId.toString() != "null") {
                        tId = int.tryParse(widget.teacherId.toString()) ?? 0;
                      }

                      if (tId == 0) {
                        final prefs = await SharedPreferences.getInstance();
                        tId =
                            prefs.getInt('user_id') ??
                            prefs.getInt('id') ??
                            prefs.getInt('teacher_id') ??
                            0;

                        if (tId == 0) {
                          String? strId =
                              prefs.getString('user_id') ??
                              prefs.getString('id') ??
                              prefs.getString('teacher_id');
                          tId = int.tryParse(strId ?? '') ?? 0;
                        }
                      }

                      if (tId == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Error: Teacher ID is missing. Please log out and log in again.",
                            ),
                            backgroundColor: Color(0xFFFC9272),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            margin: const EdgeInsets.only(
                              bottom: 24,
                              left: 16,
                              right: 16,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        setDialogState(() => isCreating = false);
                        return;
                      }

                      try {
                        final bodyPayload = jsonEncode({
                          'teacher_id': tId,
                          'name': nameCtrl.text.trim(),
                          'grade_level': selectedGrade,
                          'section': finalSection,
                        });

                        var response = await http.post(
                          Uri.parse("$baseUrl/api/classes"),
                          headers: {
                            ...networkHeaders,
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                          },
                          body: bodyPayload,
                        );

                        if (response.statusCode == 404) {
                          response = await http.post(
                            Uri.parse("$baseUrl/api/teachers/$tId/classes"),
                            headers: {
                              ...networkHeaders,
                              'Content-Type': 'application/json',
                              'Accept': 'application/json',
                            },
                            body: bodyPayload,
                          );
                        }

                        if (response.statusCode == 200 ||
                            response.statusCode == 201) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          _fetchClasses();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Class created successfully!"),
                              backgroundColor: Color(0xFF8BCA84),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              margin: const EdgeInsets.only(
                                bottom: 24,
                                left: 16,
                                right: 16,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          String errorMsg =
                              "Server Error ${response.statusCode}";
                          try {
                            final errorData = jsonDecode(response.body);
                            if (errorData['errors'] != null) {
                              errorMsg = errorData['errors'].values.first[0]
                                  .toString();
                            } else if (errorData['message'] != null) {
                              errorMsg = errorData['message'].toString();
                            }
                          } catch (_) {}
                          throw Exception(errorMsg);
                        }
                      } catch (e) {
                        if (mounted) {
                          String cleanError = e.toString().replaceAll(
                            "Exception: ",
                            "",
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cleanError),
                              backgroundColor: Color(0xFFFC9272),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              margin: const EdgeInsets.only(
                                bottom: 24,
                                left: 16,
                                right: 16,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setDialogState(() => isCreating = false);
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Create Class",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchClasses(), _fetchAnalytics()]);
  }

  @override
  Widget build(BuildContext context) {
    return ComicBackgroundWrapper(
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        color: maroonTheme,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComicBadgeHeader(title: "PHIL-IRI OVERVIEW"),
              const SizedBox(height: 10),
              if (_isLoadingAnalytics)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: maroonTheme),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              _summaryData['instructional_count']?.toString() ??
                              "0",
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          title: "Independent",
                          count:
                              _summaryData['independent_count']?.toString() ??
                              "0",
                          color: const Color(0xFF8BCA84),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  const ComicBadgeHeader(title: "LEARNERS' RECORDS"),
                  ElevatedButton.icon(
                    onPressed: _showAddStudentDialog,
                    icon: const Icon(
                      Icons.person_add,
                      color: Colors.black,
                      size: 20,
                    ),
                    label: const Text(
                      "Add Student",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentTheme,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_summaryData['students'] == null ||
                  (_summaryData['students'] as List).isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "No students enrolled yet.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      _groupStudentsByClass(
                        _summaryData['students'] as List,
                      ).map((entry) {
                        final String classLabel = entry.key;
                        final students = entry.value;
                        return _buildClassTabChip(
                          context,
                          classLabel,
                          students,
                        );
                      }).toList(),
                ),
              if (_summaryData['students'] != null)
                _buildUnassignedStudentsSection(
                  _summaryData['students'] as List,
                ),
              const SizedBox(height: 30),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  const ComicBadgeHeader(title: "YOUR CLASSES"),
                  ElevatedButton.icon(
                    onPressed: _showCreateClassDialog,
                    icon: const Icon(Icons.add, color: Colors.black, size: 20),
                    label: const Text(
                      "New Class",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentTheme,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30.0),
                    child: CircularProgressIndicator(color: maroonTheme),
                  ),
                )
              else if (_classes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "No classes created yet.",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final item = _classes[index];
                    final String className = _safeString(item['name'], 'Class');
                    final String section = _safeString(item['section']);
                    String rawGrade = _safeString(item['grade_level'], '5');
                    final String grade = rawGrade
                        .replaceAll(RegExp(r'Grade', caseSensitive: false), '')
                        .trim();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _openClassDetails(
                              context,
                              item,
                              className,
                              grade,
                              section,
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBAE6FD),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: Colors.black,
                              ),
                            ),
                            title: Text(
                              className,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              "Grade $grade${section.isNotEmpty ? ' • $section' : ''}\nCode: ${item['class_code'] ?? 'None'}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: accentTheme,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// True when a student has no real class assigned yet (only grouped under
  /// a Grade/Section bucket, or fully "Ungrouped"). Used to surface them in
  /// the "Needs Class Assignment" list so a teacher can assign one.
  bool _hasNoClassAssigned(Map<String, dynamic> student) {
    return _resolveClassInfo(student)['sortKey'].toString().startsWith('1|');
  }

  List<Map<String, dynamic>> _getUnassignedStudents(List<dynamic> rawStudents) {
    return rawStudents
        .map((s) => Map<String, dynamic>.from(s as Map))
        .where(_hasNoClassAssigned)
        .toList()
      ..sort(
        (a, b) => _safeString(
          a['name'],
        ).toLowerCase().compareTo(_safeString(b['name']).toLowerCase()),
      );
  }

  Future<void> _assignStudentToClass(
    Map<String, dynamic> student,
    dynamic classId,
  ) async {
    final studentId = student['id'] ?? student['user_id'];
    if (studentId == null || classId == null) return;

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/classes/$classId/bulk-add-students"),
        headers: {...networkHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "student_ids": [studentId],
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${_safeString(student['name'], 'Student')} assigned to class!",
            ),
            backgroundColor: const Color(0xFF8BCA84),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to assign student (${res.statusCode})."),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error assigning student to class: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error assigning student: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAssignClassPicker(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: Text(
          "Assign ${_safeString(student['name'], 'Student')} to which class?",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _classes.isEmpty
              ? const Text(
                  "You don't have any classes yet. Create a class first.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    final classId = cls['id'] ?? cls['_id'] ?? cls['class_id'];
                    final className = _safeString(
                      cls['name'] ?? cls['class_name'],
                      'Unnamed Class',
                    );
                    final gradeLevel = _safeString(cls['grade_level']);
                    return ListTile(
                      leading: const Icon(
                        Icons.class_rounded,
                        color: maroonTheme,
                      ),
                      title: Text(
                        className,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: gradeLevel.isNotEmpty ? Text(gradeLevel) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _assignStudentToClass(student, classId);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedStudentsSection(List<dynamic> rawStudents) {
    final unassigned = _getUnassignedStudents(rawStudents);
    if (unassigned.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.priority_high_rounded, color: maroonTheme),
            const SizedBox(width: 6),
            Text(
              "Needs Class Assignment (${unassigned.length})",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: maroonTheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4)),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: unassigned.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.black12),
            itemBuilder: (context, index) {
              final student = unassigned[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: accentTheme,
                  child: Text(
                    _safeString(student['name'], '?').isNotEmpty
                        ? _safeString(student['name'], '?')[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                title: Text(
                  _safeString(student['name'], 'Unknown Student'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "LRN: ${_safeString(student['lrn'], 'N/A')}",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _showAssignClassPicker(student),
                  icon: const Icon(Icons.add, size: 16, color: Colors.black),
                  label: const Text(
                    "Assign",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentTheme,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    elevation: 0,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _resolveClassInfo(Map<String, dynamic> student) {
    dynamic classField =
        student['school_classes'] ??
        student['school_class'] ??
        student['class'] ??
        student['classes'];

    String? realClassName;

    if (classField is Map) {
      final n = _safeString(classField['name']);
      if (n.isNotEmpty) realClassName = n;
    } else if (classField is List && classField.isNotEmpty) {
      final first = classField.first;
      if (first is Map) {
        final n = _safeString(first['name']);
        if (n.isNotEmpty) realClassName = n;
      }
    }

    if (realClassName == null) {
      final n1 = _safeString(student['class_name']);
      if (n1.isNotEmpty) realClassName = n1;
    }
    if (realClassName == null) {
      final n2 = _safeString(student['className']);
      if (n2.isNotEmpty) realClassName = n2;
    }

    if (realClassName != null && realClassName.isNotEmpty) {
      return {
        'label': realClassName,
        'sortKey': "0|${realClassName.toLowerCase()}",
      };
    }

    final String grade = _safeString(student['grade_level'], 'N/A');
    final String section = _safeString(student['section'], 'N/A');
    final String label = grade == 'N/A'
        ? 'Ungrouped'
        : "Grade $grade${section != 'N/A' ? ' • $section' : ''}";
    final int gradeNum =
        int.tryParse(grade.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
    final String sortKey =
        "1|${gradeNum.toString().padLeft(6, '0')}|${section.toLowerCase()}";
    return {'label': label, 'sortKey': sortKey};
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupStudentsByClass(
    List<dynamic> rawStudents,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, String> sortKeys = {};

    for (var s in rawStudents) {
      final student = Map<String, dynamic>.from(s as Map);
      final info = _resolveClassInfo(student);
      final String label = info['label'] as String;
      sortKeys[label] = info['sortKey'] as String;
      grouped.putIfAbsent(label, () => []).add(student);
    }

    for (var list in grouped.values) {
      list.sort(
        (a, b) => _safeString(
          a['name'],
        ).toLowerCase().compareTo(_safeString(b['name']).toLowerCase()),
      );
    }

    final sortedLabels = grouped.keys.toList()
      ..sort((a, b) => sortKeys[a]!.compareTo(sortKeys[b]!));

    return sortedLabels
        .map((label) => MapEntry(label, grouped[label]!))
        .toList();
  }

  Widget _buildClassTabChip(
    BuildContext context,
    String classLabel,
    List<Map<String, dynamic>> students,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openClassStudentsPopup(context, classLabel, students),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: accentTheme,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.class_rounded,
                  size: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                classLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentTheme,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  "${students.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openClassStudentsPopup(
    BuildContext context,
    String classLabel,
    List<Map<String, dynamic>> students,
  ) {
    _studentSearchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final filteredStudents = _studentSearchQuery.isEmpty
                    ? students
                    : students.where((s) {
                        final name = _safeString(s['name'], '').toLowerCase();
                        return name.contains(_studentSearchQuery);
                      }).toList();

                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4B2C2),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.black, width: 3.5),
                      left: BorderSide(color: Colors.black, width: 3.5),
                      right: BorderSide(color: Colors.black, width: 3.5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: accentTheme,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(3, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              classLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: maroonTheme,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          "${filteredStudents.length} student${filteredStudents.length == 1 ? '' : 's'} • sorted A–Z",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: TextField(
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search student name...",
                            hintStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black45,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                            suffixIcon: _studentSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.black54,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        _studentSearchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              _studentSearchQuery = value.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: filteredStudents.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text(
                                    "No students match your search.",
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  return _buildStudentSummaryRow(
                                    student,
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      _openStudentProfilePopup(
                                        context,
                                        student,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openStudentProfilePopup(
    BuildContext context,
    Map<String, dynamic> student,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 40,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
            decoration: BoxDecoration(
              color: const Color(0xFFD4B2C2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 3.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(5, 5)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentTheme,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2.5),
                      ),
                      child: ClipOval(
                        child:
                            (student['avatar'] != null &&
                                student['avatar'].toString().isNotEmpty)
                            ? Image.network(
                                student['avatar'].toString().startsWith('http')
                                    ? student['avatar']
                                    : "$baseUrl${student['avatar']}",
                                fit: BoxFit.cover,
                                headers: const {
                                  "ngrok-skip-browser-warning": "69420",
                                },
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.person,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _safeString(student['name'], 'Student'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Grade ${_safeString(student['grade'], 'N/A')} • ${_safeString(student['section'], 'N/A')}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: maroonTheme,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildLearnerRecordCard(student),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentSummaryRow(
    Map<String, dynamic> student, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap:
              onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _StudentRecordScreen(
                      studentName: _safeString(student['name'], 'Student'),
                      recordCard: _buildLearnerRecordCard(student),
                    ),
                  ),
                );
              },
          child: ListTile(
            leading: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE047),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: ClipOval(
                child:
                    (student['avatar'] != null &&
                        student['avatar'].toString().isNotEmpty)
                    ? Image.network(
                        student['avatar'].toString().startsWith('http')
                            ? student['avatar']
                            : "$baseUrl${student['avatar']}",
                        fit: BoxFit.cover,
                        headers: const {"ngrok-skip-browser-warning": "69420"},
                        errorBuilder: (ctx, err, stack) =>
                            const Icon(Icons.person, color: Colors.black),
                      )
                    : const Icon(Icons.person, color: Colors.black, size: 24),
              ),
            ),
            title: Text(
              _safeString(student['name'], 'Unknown Student'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Grade ${_safeString(student['grade'], 'N/A')} - ${_safeString(student['section'], 'N/A')}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearnerRecordCard(dynamic student) {
    final Map<String, dynamic> s = Map<String, dynamic>.from(student as Map);
    final studentId = s['id'] ?? s['user_id'];

    return FutureBuilder<List<dynamic>>(
      future: _fetchStudentProgress(studentId),
      builder: (context, snapshot) {
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;
        final List progressLogs = snapshot.data ?? [];
        return _buildLearnerRecordCardContent(
          s,
          progressLogs,
          isLoading: isLoading,
        );
      },
    );
  }

  Widget _buildLearnerRecordCardContent(
    Map<String, dynamic> student,
    List progressLogs, {
    bool isLoading = false,
  }) {
    List studentMispronunciations = _mispronunciations
        .where((m) => m['student_id'] == student['id'])
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade400,
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
                      _safeString(student['name'], 'N/A'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${_safeString(student['grade_level'])} ${_safeString(student['section'])}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _safeString(student['lrn'], 'N/A'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: Colors.brown),
              ),
            )
          else if (progressLogs.isEmpty)
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
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(2),
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
                  ],
                ),
                ...progressLogs.map((log) {
                  List storyWords = studentMispronunciations
                      .where((m) => m['story_id'] == log['story_id'])
                      .toList();
                  String wordsText = storyWords.isEmpty
                      ? "None"
                      : storyWords
                            .map(
                              (w) => "${w['word']} (${w['total_attempts']}x)",
                            )
                            .join(", ");

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
                        child: Text(
                          _safeString(log['reading_level'], 'N/A'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
                        child: Text(
                          _safeString(log['oral_fluency_accuracy'], 'N/A') +
                              (log['oral_fluency_accuracy'] != null ? '%' : ''),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
                    ],
                  );
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }
}

class _StudentRecordScreen extends StatelessWidget {
  final String studentName;
  final Widget recordCard;

  const _StudentRecordScreen({
    required this.studentName,
    required this.recordCard,
  });

  static const Color maroonTheme = Color(0xFF940D0D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4B2C2),
      appBar: AppBar(
        backgroundColor: maroonTheme,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "$studentName's Records 📖",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: recordCard,
        ),
      ),
    );
  }
}

class _ClassDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String className;
  final String grade;
  final String section;
  final Widget Function(Map<String, dynamic>)? buildRecordCard;

  const _ClassDetailsSheet({
    required this.item,
    required this.className,
    required this.grade,
    required this.section,
    this.buildRecordCard,
  });

  @override
  State<_ClassDetailsSheet> createState() => _ClassDetailsSheetState();
}

class _ClassDetailsSheetState extends State<_ClassDetailsSheet> {
  static const Color maroonTheme = Color(0xFF940D0D);
  static const Color accentTheme = Color(0xFFFDE047);
  static const List<String> _assessmentSets = ['A', 'B', 'C', 'D'];

  List<Map<String, dynamic>> _assignedStories = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStories = true;
  bool _isLoadingStudents = true;

  @override
  void initState() {
    super.initState();
    _fetchClassStories();
    _fetchClassStudents();
  }

  Future _fetchClassStories() async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];

    List<dynamic> localRaw =
        widget.item['assigned_stories'] ??
        widget.item['assignedStories'] ??
        widget.item['stories'] ??
        [];

    if (localRaw.isNotEmpty) {
      final List<Map<String, dynamic>> cleanList = [];
      for (var s in localRaw) {
        if (s is Map) cleanList.add(Map<String, dynamic>.from(s));
      }
      if (cleanList.isNotEmpty && mounted) {
        setState(() {
          _assignedStories = cleanList;
          _isLoadingStories = false;
        });
      }
    }

    try {
      final res1 = await http.get(
        Uri.parse("$baseUrl/api/classes/$classId/stories"),
        headers: networkHeaders,
      );
      if (res1.statusCode == 200) {
        final decoded = jsonDecode(res1.body);
        final list = _extractStoriesList(decoded);
        if (mounted) setState(() => _assignedStories = list);
        if (list.isNotEmpty && mounted) {
          setState(() => _isLoadingStories = false);
          return;
        }
      }
    } catch (_) {}

    try {
      final res2 = await http.get(
        Uri.parse("$baseUrl/api/classes/$classId"),
        headers: networkHeaders,
      );
      if (res2.statusCode == 200) {
        final decoded = jsonDecode(res2.body);
        final list = _extractStoriesList(decoded);
        if (mounted) setState(() => _assignedStories = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingStories = false);
    }
  }

  List<Map<String, dynamic>> _extractStoriesList(dynamic decoded) {
    List raw = [];
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map) {
      raw =
          decoded['assigned_stories'] ??
          decoded['assignedStories'] ??
          decoded['stories'] ??
          decoded['data'] ??
          [];
    }
    final List<Map<String, dynamic>> result = [];
    for (var item in raw) {
      if (item is Map) result.add(Map<String, dynamic>.from(item));
    }
    return result;
  }

  Future _fetchClassStudents() async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];

    List<dynamic> localStudents =
        widget.item['students'] ?? widget.item['enrolled_students'] ?? [];

    if (localStudents.isNotEmpty) {
      final List<Map<String, dynamic>> cleanList = [];
      for (var s in localStudents) {
        if (s is Map) cleanList.add(Map<String, dynamic>.from(s));
      }
      if (mounted) {
        setState(() {
          _students = cleanList;
          _isLoadingStudents = false;
        });
      }
    }

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/classes/$classId/students"),
        headers: networkHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        final decoded = jsonDecode(res.body);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          rawList = decoded['students'] ?? decoded['data'] ?? [];
        }
        final List<Map<String, dynamic>> cleanList = [];
        for (var s in rawList) {
          if (s is Map) cleanList.add(Map<String, dynamic>.from(s));
        }
        setState(() {
          _students = cleanList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  // ---------------------------------------------------------------------
  // Teacher: assign a Phil-IRI Reading Test (pre-test or post-test) to one
  // student. This is the actual "Assign a Reading Test" action the Stories
  // tab's banner points to.
  // ---------------------------------------------------------------------

  int? get _classGrade => int.tryParse(widget.grade);

  // Same normalization the backend applies (strtoupper(trim(str_ireplace(
  // 'Set', '', ...)))), so "A" and "Set A" compare equal here too.
  String _normalizeSetLetter(String s) => s
      .replaceAll(RegExp('set', caseSensitive: false), '')
      .trim()
      .toUpperCase();

  /// Finds this student's existing assessment (any status) for the given
  /// test_type + set combo, from a raw /assessments list. Used so the
  /// assign dialog can warn before silently overwriting one.
  Map<String, dynamic>? _findMatchingAssessment(
    List<dynamic> all,
    String testType,
    String setLetter,
  ) {
    final wantSet = _normalizeSetLetter(setLetter);
    for (final raw in all) {
      if (raw is! Map) continue;
      final a = Map<String, dynamic>.from(raw);
      if (_safeString(a['test_type']) != testType) continue;
      if (_normalizeSetLetter(_safeString(a['set_letter'])) != wantSet) {
        continue;
      }
      return a;
    }
    return null;
  }

  String _describeExistingAssessment(Map<String, dynamic> a) {
    final status = _safeString(a['status'], 'assigned');
    final label = _safeString(a['test_type']) == 'pre_test'
        ? 'Pre-Test'
        : 'Post-Test';
    final set = _safeString(a['set_letter']);
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
      return 'Already completed this $label, Set $set$detail.';
    }
    return 'Already assigned this $label, Set $set — not yet completed.';
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

  // ---------------------------------------------------------------------
  // Teacher: randomly assign a reading test to every student in the class
  // at once (Stories tab). No GST here — every student starts at the
  // class's own grade level. This is a deliberately different, simpler
  // path than _showAssignAssessmentDialog below; that one is untouched.
  // ---------------------------------------------------------------------

  Future<void> _showBulkShuffleAssignDialog() async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];
    final int? classGrade = _classGrade;

    if (classGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This class has no grade level set.")),
      );
      return;
    }

    String selectedTestType = 'pre_test';
    bool isSubmitting = false;
    String? errorText;

    final List<dynamic>? assignments = await showDialog<List<dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 3.5),
          ),
          backgroundColor: accentTheme,
          title: const Text(
            "Randomly Assign to Class",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Every one of the ${_students.length} students in this "
                "class (Grade $classGrade) gets a randomly picked Set "
                "(A-D) — independently per student, so the split won't "
                "be even. No GST score is used; everyone starts at "
                "Grade $classGrade.",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pre_test', label: Text('Pre-Test')),
                  ButtonSegment(value: 'post_test', label: Text('Post-Test')),
                ],
                selected: {selectedTestType},
                onSelectionChanged: isSubmitting
                    ? null
                    : (v) => setDialogState(() {
                        selectedTestType = v.first;
                        errorText = null;
                      }),
              ),
              const SizedBox(height: 10),
              const Text(
                "Reassigning a student who already has one for this test "
                "type replaces it (a fresh Set, fresh attempt) — any saved "
                "result on it is erased.",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
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
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        final response = await http.post(
                          Uri.parse(
                            "$baseUrl/api/classes/$classId/assessments/bulk",
                          ),
                          headers: {
                            ...networkHeaders,
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                          },
                          body: jsonEncode({
                            'test_type': selectedTestType,
                            'student_ids': _students
                                .map((s) => s['id'] ?? s['_id'])
                                .toList(),
                            'student_grade': classGrade,
                          }),
                        );
                        if ((response.statusCode == 200 ||
                                response.statusCode == 201) &&
                            mounted) {
                          final decoded = jsonDecode(response.body);
                          final list =
                              (decoded is Map ? decoded['assessments'] : null)
                                  as List<dynamic>? ??
                              [];
                          Navigator.pop(dialogContext, list);
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errorText =
                                'Failed to assign (code ${response.statusCode}). Try again.';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = 'Network error: $e';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Shuffle & Assign",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    if (assignments == null || !mounted) return;

    // Build a quick id -> name lookup from the roster already loaded for
    // this class, so the result list reads as names, not raw IDs.
    final Map<String, String> nameById = {
      for (final s in _students)
        _safeString(s['id'] ?? s['_id']): _safeString(
          s['name'] ?? s['username'],
          'Student',
        ),
    };

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Done — Sets Assigned"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: assignments.length,
            itemBuilder: (_, i) {
              final a = Map<String, dynamic>.from(assignments[i] as Map);
              final name = nameById[_safeString(a['student_id'])] ?? 'Student';
              return ListTile(
                dense: true,
                title: Text(name),
                trailing: Text(
                  "Set ${_safeString(a['set_letter'])}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignAssessmentDialog(Map<String, dynamic> student) async {
    final dynamic studentId = student['id'] ?? student['_id'];
    if (studentId == null) return;

    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];
    final String studentName = _safeString(
      student['name'] ?? student['username'],
      'this student',
    );
    final int? classGrade = _classGrade;

    final gstController = TextEditingController();
    String selectedTestType = 'pre_test';
    String selectedSet = _assessmentSets.first;
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
                    "$baseUrl/api/classes/$classId/assessments"
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
                      initialValue: postTestStartGrade,
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
                    initialValue: selectedSet,
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
                        selectedSet,
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
                              _describeExistingAssessment(match),
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
                        // assignment/outcome for this exact test_type + set.
                        final existingMatch = existingLoaded
                            ? _findMatchingAssessment(
                                existingForStudent,
                                selectedTestType,
                                selectedSet,
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
                          final int studentIdInt = studentId is int
                              ? studentId
                              : (int.tryParse(studentId.toString()) ?? 0);
                          final session = PhilIriSession.forPreTest(
                            studentId: studentIdInt,
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
                              "$baseUrl/api/classes/$classId/assessments",
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

  Future<void> _unassignStory(dynamic storyId, String testType) async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unassign Story"),
        content: Text(
          "Are you sure you want to unassign this story (${testType == 'pre_test' ? 'Pre-test' : 'Post-test'}) from this class?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF940D0D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "UNASSIGN",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final Map<String, String> headers = Map<String, String>.from(
        networkHeaders,
      )..['Content-Type'] = 'application/json';

      final res = await http.post(
        Uri.parse("$baseUrl/api/classes/$classId/unassign-story"),
        headers: headers,
        body: jsonEncode({"story_id": storyId, "test_type": testType}),
      );

      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Story unassigned successfully."),
            backgroundColor: Color(0xFF8BCA84),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );

        _fetchClassStories();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed to unassign story. Status code: ${res.statusCode}",
              ),
              backgroundColor: Color(0xFFFC9272),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error unassigning story: $e"),
            backgroundColor: Color(0xFFFC9272),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future _deleteClass() async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: const Text(
          "Delete Class?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text("Are you sure you want to delete '${widget.className}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF940D0D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/api/classes/$classId"),
        headers: networkHeaders,
      );
      if ((res.statusCode == 200 || res.statusCode == 204) && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Class deleted successfully"),
            backgroundColor: Color(0xFF8BCA84),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete class. Status code: ${res.statusCode}",
            ),
            backgroundColor: Color(0xFFFC9272),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete class: $e"),
            backgroundColor: const Color(0xFFFC9272),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.black, width: 3.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.className,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "Grade ${widget.grade}${widget.section.isNotEmpty ? ' • ${widget.section}' : ''}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.black,
                    size: 26,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') _deleteClass();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "Delete Class",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // TAB BAR (STORIES / STUDENTS)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFBAE6FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const TabBar(
                indicatorColor: Color(0xFF940D0D),
                indicatorWeight: 4,
                labelColor: Color(0xFF940D0D),
                unselectedLabelColor: Colors.black,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(icon: Icon(Icons.menu_book), text: "Stories"),
                  Tab(icon: Icon(Icons.people), text: "Students"),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // TAB VIEWS
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: ASSIGNED STORIES
                  Column(
                    children: [
                      // Pre-test / post-test assignment now goes through the
                      // Phil-IRI GST flow on the Students tab, so a story can no
                      // longer be assigned by hand here (that bypassed GST
                      // scoring, the starting grade and the branching search).
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBAE6FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Text(
                          "Assign a Reading Test from the Students tab. It "
                          "walks through the GST score and the Phil-IRI "
                          "passage set automatically.",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingStudents || _students.isEmpty
                              ? null
                              : _showBulkShuffleAssignDialog,
                          icon: const Icon(Icons.shuffle),
                          label: Text(
                            _students.isEmpty
                                ? "No students in this class yet"
                                : "Randomly Assign to Class (${_students.length} students)",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: maroonTheme,
                            side: const BorderSide(
                              color: maroonTheme,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: _isLoadingStories
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF940D0D),
                                ),
                              )
                            : _assignedStories.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBAE6FD),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Text(
                                    "No stories assigned to this class yet.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                itemCount: _assignedStories.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 350,
                                      crossAxisSpacing: 15,
                                      mainAxisSpacing: 15,
                                      childAspectRatio: 0.72,
                                    ),
                                itemBuilder: (context, index) {
                                  final story = _assignedStories[index];
                                  List<dynamic> pages = story['pages'] is List
                                      ? story['pages']
                                      : [];

                                  // 🛠️ FIXED COVER URL LOGIC HERE
                                  String rawCoverPath = _safeString(
                                    story['cover_image'],
                                  );
                                  String coverUrl = "";
                                  if (rawCoverPath.isNotEmpty) {
                                    if (rawCoverPath.startsWith('http')) {
                                      coverUrl = rawCoverPath;
                                    } else {
                                      if (rawCoverPath.startsWith('public/')) {
                                        rawCoverPath = rawCoverPath
                                            .replaceFirst('public/', '');
                                      }
                                      String cleanBaseUrl =
                                          baseUrl.endsWith('/api')
                                          ? baseUrl.substring(
                                              0,
                                              baseUrl.length - 4,
                                            )
                                          : baseUrl;
                                      coverUrl =
                                          "$cleanBaseUrl/api/get-image?path=$rawCoverPath";
                                    }
                                  }

                                  final Map<String, dynamic>? pivot =
                                      story['pivot'] is Map
                                      ? Map<String, dynamic>.from(
                                          story['pivot'],
                                        )
                                      : null;
                                  final String storyTestType =
                                      pivot?['test_type'] ?? 'post_test';

                                  return Stack(
                                    children: [
                                      BouncyTap(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StoryViewerScreen(
                                                story: story,
                                                baseUrl: baseUrl,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: 3,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black,
                                                offset: Offset(4, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          13,
                                                        ),
                                                      ),
                                                  child: coverUrl.isNotEmpty
                                                      ? Image.network(
                                                          coverUrl,
                                                          fit: BoxFit.cover,
                                                          headers: const {
                                                            "ngrok-skip-browser-warning":
                                                                "69420",
                                                          },
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Container(
                                                                color:
                                                                    const Color(
                                                                      0xFFFDE047,
                                                                    ),
                                                                child: const Icon(
                                                                  Icons.image,
                                                                  color: Colors
                                                                      .black87,
                                                                  size: 35,
                                                                ),
                                                              ),
                                                        )
                                                      : Container(
                                                          color: const Color(
                                                            0xFFFDE047,
                                                          ),
                                                          child: const Icon(
                                                            Icons.image,
                                                            color:
                                                                Colors.black87,
                                                            size: 35,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const Divider(
                                                color: Colors.black,
                                                thickness: 3,
                                                height: 3,
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        _safeString(
                                                          story['title'],
                                                          'Untitled',
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 14,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${pages.length} Pages",
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        left: 5,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    storyTestType == 'pre_test'
                                                    ? const Color(0xFF800000)
                                                    : const Color(0xFF287A7A),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.black,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Text(
                                                storyTestType == 'pre_test'
                                                    ? "PRE-TEST"
                                                    : "POST-TEST",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            if (story['quiz'] != null)
                                              const SizedBox(height: 4),
                                            if (story['quiz'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF8BCA84),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Text(
                                                  "With Quiz",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        StoryEditorScreen(
                                                          story: story,
                                                          baseUrl: baseUrl,
                                                        ),
                                                  ),
                                                ).then((_) {
                                                  _fetchClassStories();
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                margin: const EdgeInsets.only(
                                                  right: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.settings,
                                                  color: Colors.blue,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _unassignStory(
                                                story['id'] ?? story['_id'],
                                                storyTestType,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  // TAB 2: ENROLLED STUDENTS LIST
                  Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDE047),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.group_add, color: Colors.black),
                        label: const Text(
                          "Add Students from Masterlist",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () => _showAddStudentsSheet(context),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: _isLoadingStudents
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF940D0D),
                                ),
                              )
                            : _students.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBAE6FD),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Text(
                                    "No students joined in this class yet.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  final name = _safeString(
                                    student['name'] ?? student['username'],
                                    'Student',
                                  );
                                  final email = _safeString(
                                    student['email'],
                                    'No email',
                                  );

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        if (widget.buildRecordCard != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _StudentRecordScreen(
                                                    studentName: _safeString(
                                                      student['name'],
                                                      'Student',
                                                    ),
                                                    recordCard:
                                                        widget.buildRecordCard!(
                                                          student,
                                                        ),
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      leading: Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDE047),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child:
                                              (student['avatar'] != null &&
                                                  student['avatar']
                                                      .toString()
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  student['avatar']
                                                          .toString()
                                                          .startsWith('http')
                                                      ? student['avatar']
                                                      : "$baseUrl${student['avatar']}",
                                                  fit: BoxFit.cover,
                                                  headers: const {
                                                    "ngrok-skip-browser-warning":
                                                        "69420",
                                                  },
                                                  errorBuilder:
                                                      (ctx, err, stack) =>
                                                          const Icon(
                                                            Icons.person,
                                                            color: Colors.black,
                                                          ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  color: Colors.black,
                                                  size: 24,
                                                ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        email,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentTheme,
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.black,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showAssignAssessmentDialog(
                                              student,
                                            ),
                                        child: const Text(
                                          "Assign Test",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddStudentsSheet(BuildContext context) async {
    final classId =
        widget.item['id'] ?? widget.item['_id'] ?? widget.item['class_id'];
    List<dynamic> availableStudents = [];
    bool isLoading = true;
    bool isSaving = false;
    Set<int> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isLoading && availableStudents.isEmpty) {
              http
                  .get(
                    Uri.parse(
                      "$baseUrl/api/classes/$classId/available-students",
                    ),
                    headers: networkHeaders,
                  )
                  .then((res) {
                    if (res.statusCode == 200 && mounted) {
                      final decoded = jsonDecode(res.body);
                      setSheetState(() {
                        availableStudents = decoded['data'] ?? [];
                        isLoading = false;
                      });
                    }
                  })
                  .catchError((e) {
                    setSheetState(() => isLoading = false);
                  });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: const Color(0xFFD4B2C2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: Colors.black, width: 3.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add to Class",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF940D0D),
                            ),
                          )
                        : availableStudents.isEmpty
                        ? const Center(
                            child: Text(
                              "No new students available for this Grade and Section.",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        : ListView.builder(
                            itemCount: availableStudents.length,
                            itemBuilder: (context, index) {
                              final student = availableStudents[index];
                              final studentId = student['id'];
                              final isSelected = selectedIds.contains(
                                studentId,
                              );

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  activeColor: const Color(0xFF8BCA84),
                                  checkColor: Colors.black,
                                  value: isSelected,
                                  onChanged: (val) {
                                    setSheetState(() {
                                      if (val == true) {
                                        selectedIds.add(studentId);
                                      } else {
                                        selectedIds.remove(studentId);
                                      }
                                    });
                                  },
                                  title: Text(
                                    student['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "LRN: ${student['lrn'] ?? 'N/A'}",
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (selectedIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF940D0D),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                final res = await http.post(
                                  Uri.parse(
                                    "$baseUrl/api/classes/$classId/bulk-add-students",
                                  ),
                                  headers: {
                                    ...networkHeaders,
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode({
                                    "student_ids": selectedIds.toList(),
                                  }),
                                );
                                if (res.statusCode == 200) {
                                  if (mounted) Navigator.pop(ctx);
                                  _fetchClassStudents();
                                }
                                setSheetState(() => isSaving = false);
                              },
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                "Add ${selectedIds.length} Students",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
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
}

class _AlertsTab extends StatefulWidget {
  final dynamic teacherId;
  const _AlertsTab({this.teacherId});

  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  static const Color maroonTheme = Color(0xFF940D0D);
  static const Color accentTheme = Color(0xFFFDE047);
  bool _isLoading = true;
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      int tId = 0;
      if (widget.teacherId != null && widget.teacherId.toString() != "null") {
        tId = int.tryParse(widget.teacherId.toString()) ?? 0;
      }
      if (tId == 0) {
        final prefs = await SharedPreferences.getInstance();
        tId =
            prefs.getInt('user_id') ??
            prefs.getInt('id') ??
            prefs.getInt('teacher_id') ??
            1;
      }

      final response = await http.get(
        Uri.parse("$baseUrl/api/teachers/$tId/alerts"),
        headers: networkHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _alerts = decoded['data'] ?? decoded;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading alerts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ComicBackgroundWrapper(
      child: RefreshIndicator(
        onRefresh: _fetchAlerts,
        color: maroonTheme,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComicBadgeHeader(title: "NEEDS INTERVENTION ⚠️"),
              const SizedBox(height: 15),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: CircularProgressIndicator(color: maroonTheme),
                  ),
                )
              else if (_alerts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_rounded,
                        size: 70,
                        color: Color(0xFF8BCA84),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Great! No students are stuck in Frustration level.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.shade900,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.shade900,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            color: Colors.red.shade900,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          _safeString(alert['student_name'], 'Unknown Student'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "Reason: ${_safeString(alert['reason'], 'Consistently at Frustration Level')}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Class: ${_safeString(alert['class_name'], 'N/A')}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentTheme,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          onPressed: () {
                            // TODO: Action kapag pinindot (e.g. view student profile o message)
                          },
                          child: const Text(
                            "Review",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
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
    );
  }
}
