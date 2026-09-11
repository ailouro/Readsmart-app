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
                  _AlertsTab(teacherId: widget.teacherId), // ⚠️ BAGONG TAB MO
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
              icon: Icon(Icons.warning_amber_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt),
              label: 'Students',
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
                  isActive:
                      _selectedIndex == 3, // ⚠️ NAGING INDEX 3 NA ANG PROFILE
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
                  _AlertsTab(teacherId: widget.teacherId), // ⚠️ BAGONG TAB MO
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
class _TopHeaderBar extends StatelessWidget {
  final String userName;
  final dynamic teacherId;
  final VoidCallback onLogout;

  const _TopHeaderBar({
    required this.userName,
    this.teacherId,
    required this.onLogout,
  });

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
                  userName.isNotEmpty ? userName : "Teacher",
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.black, size: 20),
              onPressed: onLogout,
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
    // Same slow, gentle rotation used on the student dashboard's
    // spinning background.
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

    // Solid backdrop stays fixed; only the rays spin around the center.
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
            // Non-interactive section label: white instead of the
            // button-yellow (accentTheme) so it doesn't look tappable
            // next to real actions like "Create New Story".
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

  // 1. Early return if the widget is no longer in the tree after the async gap
  if (!mounted) return;

  // 2. Safely use context now that we know the widget is mounted
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
    
    
    // Note: Calling fetchStories() works, but redownloads all data. 
    // For better performance, consider using setState to remove the story from your local list instead.
    fetchStories(); 
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("Failed to delete story. Status code: ${res.statusCode}"),
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
  // 3. Check mounted again after the catch block's potential async gap
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
              const ComicBadgeHeader(title: "YOUR LIBRARY"),
              const SizedBox(height: 10),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: CircularProgressIndicator(color: maroonTheme),
                  ),
                )
              else if (_stories.isEmpty)
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
                    child: const Column(
                      children: [
                        Icon(
                          Icons.auto_stories,
                          size: 70,
                          color: Colors.black54,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "No stories published yet.",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stories.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    List pages = story['pages'] is List ? story['pages'] : [];
                    String rawCoverPath = _safeString(story['cover_image']);
                    if (rawCoverPath.startsWith('public/')) {
                      rawCoverPath = rawCoverPath.replaceFirst('public/', '');
                    }
                    String cleanBaseUrl = baseUrl.endsWith('/api')
                        ? baseUrl.substring(0, baseUrl.length - 4)
                        : baseUrl;
                    String coverUrl =
                        "$cleanBaseUrl/api/get-image?path=$rawCoverPath";

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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.black,
                                width: 3.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
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
                                    child: Image.network(
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _safeString(
                                            story['title'],
                                            'Untitled',
                                          ),
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
                          child: (story['quiz'] != null)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF8BCA84),
                                    borderRadius: BorderRadius.circular(8),
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
                                )
                              : const SizedBox.shrink(),
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
                                      builder: (context) => StoryEditorScreen(
                                        story: story,
                                        baseUrl: baseUrl,
                                      ),
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
                                onTap: () =>
                                    _deleteStory(story['id'] ?? story['_id']),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
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
            ],
          ),
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _fetchAnalytics();
  }

  Future _fetchAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      // Resolve teacher ID the same way _fetchClasses does
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
          // ✅ Unwrap 'data' key if API wraps the response
          _summaryData = decodedSummary['data'] ?? decodedSummary;
          // ✅ Handle multiple possible keys for mispronunciations
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

      // Kunin ang tamang teacher ID
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

        // --- ANG BINAGONG LOGIC PARA MA-READ ANG CLASSES ---
        List<dynamic> rawList = [];

        if (decoded is List) {
          // Kung ang response ay diretsong Array []
          rawList = decoded;
        } else if (decoded is Map) {
          // Kung ang response ay Object na may "classes" o "data" key {"classes": []}
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

  // === NAIDAGDAG: FUNCTION PARA SA CREATE CLASS DIALOG ===
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
                  items: ['Grade 5', 'Grade 6']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
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
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
    duration: const Duration(seconds: 2),
  ),
);
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      String finalSection = sectionCtrl.text.trim();
                      if (finalSection.isEmpty) finalSection = "N/A";

                      // ROBUST TEACHER ID FETCHING: Kunin ang tamang ID galing sa memory
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
    content: Text("Error: Teacher ID is missing. Please log out and log in again.",),
    backgroundColor: Color(0xFFFC9272),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
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
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
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
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
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
                          color: Color(0xFF8BCA84).shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              const ComicBadgeHeader(title: "LEARNERS' RECORDS"),
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
                // === CLASS TABS: tap a class chip to pop up its sorted student list ===
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
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  // === GROUP STUDENTS PER CLASS (Grade + Section), sorted ascending ===
  // === Try to resolve a REAL class name/id from the student record first.
  // Checks several common Laravel API shapes; falls back to Grade+Section
  // (the old proxy) only if no real class relation is present yet. ===
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

    // Flat fallbacks some APIs use instead of a nested object
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

    // --- FALLBACK: Grade + Section proxy (used until API returns class) ---
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

    // Sort students inside each class alphabetically (A-Z) by name
    for (var list in grouped.values) {
      list.sort(
        (a, b) => _safeString(
          a['name'],
        ).toLowerCase().compareTo(_safeString(b['name']).toLowerCase()),
      );
    }

    // Sort the classes themselves using their resolved sort key
    final sortedLabels = grouped.keys.toList()
      ..sort((a, b) => sortKeys[a]!.compareTo(sortKeys[b]!));

    return sortedLabels
        .map((label) => MapEntry(label, grouped[label]!))
        .toList();
  }

  // === CLASS TAB CHIP: tap a class to pop up its sorted student list ===
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

  // === CLASS STUDENTS POPUP: sorted (A-Z) list of students in the tapped class ===
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

  // === STUDENT PROFILE POPUP: opens the learner's record inside a popup dialog ===
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
    List progressLogs = student['progress'] ?? [];

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

// ==========================================
// STUDENT RECORD SCREEN — opens when a learner's name is tapped
// (same comic design language, pushed as its own screen/"tab")
// ==========================================
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

// 2-TAB CLASS DETAIL DIALOG (STORIES & STUDENTS + SETTINGS)
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
    content: Text( "Failed to unassign story. Status code: ${res.statusCode}",),
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
       
      }
    } catch (e) {
      debugPrint("Error deleting class: $e");
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
                // SETTINGS OPTION (DELETE CLASS)
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDE047),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text(
                          "Assign Story to this Class",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () async {
                          final bool? assigned =
                              await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _StoryPickerSheet(
                                  classId: classId,
                                  className: widget.className,
                                ),
                              );

                          if (!mounted) return;

                          setState(() => _isLoadingStories = true);
                          _fetchClassStories();
                        },
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
                                  String rawCoverPath = _safeString(
                                    story['cover_image'],
                                  );
                                  if (rawCoverPath.startsWith('public/')) {
                                    rawCoverPath = rawCoverPath.replaceFirst(
                                      'public/',
                                      '',
                                    );
                                  }
                                  String cleanBaseUrl = baseUrl.endsWith('/api')
                                      ? baseUrl.substring(0, baseUrl.length - 4)
                                      : baseUrl;
                                  String coverUrl =
                                      "$cleanBaseUrl/api/get-image?path=$rawCoverPath";

                                  // The test_type this story is assigned as
                                  // in THIS class (pre_test/post_test) — a
                                  // story can be assigned twice (once as
                                  // each), so always show which one this
                                  // tile is.
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
                                                  child: Image.network(
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
                  _isLoadingStudents
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
                                        builder: (_) => _StudentRecordScreen(
                                          studentName: _safeString(
                                            student['name'],
                                            'Student',
                                          ),
                                          recordCard: widget.buildRecordCard!(
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
                                            errorBuilder: (ctx, err, stack) =>
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
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// STORY PICKER SHEET
class _StoryPickerSheet extends StatefulWidget {
  final dynamic classId;
  final String className;

  const _StoryPickerSheet({required this.classId, required this.className});

  @override
  State<_StoryPickerSheet> createState() => _StoryPickerSheetState();
}

class _StoryPickerSheetState extends State<_StoryPickerSheet> {
  List<Map<String, dynamic>> _stories = [];
  bool _isLoading = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future _fetchStories() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/stories"),
        headers: networkHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final dynamic decoded = jsonDecode(response.body);
        List rawList = decoded is List ? decoded : [];
        final List<Map<String, dynamic>> cleanList = [];
        for (var item in rawList) {
          if (item is Map) {
            cleanList.add(Map<String, dynamic>.from(item));
          }
        }
        setState(() => _stories = cleanList);
      }
    } catch (e) {
      debugPrint("Error fetching stories for assignment: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Set<dynamic> _selectedStoryIds = {};
  String _selectedTestType = "pre_test";

  Future _assignSelectedStories() async {
    if (widget.classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("Error: Invalid Class ID"),
    backgroundColor: Color(0xFFFC9272),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
    duration: const Duration(seconds: 2),
  ),
);
     
      return;
    }

    if (_selectedStoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("Please select at least one story."),
    backgroundColor: Color(0xFFFFB347),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
    duration: const Duration(seconds: 2),
  ),
);
      
      return;
    }

    setState(() => _isAssigning = true);
    try {
      final Map<String, String> headers = Map<String, String>.from(
        networkHeaders,
      )..['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse("$baseUrl/api/classes/${widget.classId}/assign-story"),
        headers: headers,
        body: jsonEncode({
          "story_id": _selectedStoryIds.toList(),
          "test_type": _selectedTestType,
        }),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        Navigator.pop(context, true); // Return 'true' on success
        ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("${_selectedStoryIds.length} story/stories assigned successfully!",),
    backgroundColor: Color(0xFF8BCA84),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
    duration: const Duration(seconds: 2),
  ),
);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("Failed to assign stories (Status: ${response.statusCode})",),
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
    content: Text("Failed to assign story: $e"),
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
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD4B2C2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.black, width: 3.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ComicBadgeHeader(
                  title: "SELECT A STORY FOR ${widget.className.toUpperCase()}",
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _isLoading || _isAssigning
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF940D0D)),
                  )
                : _stories.isEmpty
                ? const Center(
                    child: Text(
                      "No stories available in library to assign.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                : GridView.builder(
                    itemCount: _stories.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 350,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.72,
                        ),
                    itemBuilder: (context, index) {
                      final story = _stories[index];
                      final storyId = story['id'] ?? story['_id'];
                      List pages = story['pages'] is List ? story['pages'] : [];
                      String rawCoverPath = _safeString(story['cover_image']);
                      if (rawCoverPath.startsWith('public/')) {
                        rawCoverPath = rawCoverPath.replaceFirst('public/', '');
                      }
                      String cleanBaseUrl = baseUrl.endsWith('/api')
                          ? baseUrl.substring(0, baseUrl.length - 4)
                          : baseUrl;
                      String coverUrl =
                          "$cleanBaseUrl/api/get-image?path=$rawCoverPath";

                      bool isSelected = _selectedStoryIds.contains(storyId);

                      return BouncyTap(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedStoryIds.remove(storyId);
                            } else {
                              _selectedStoryIds.add(storyId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.amber[100]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Color(0xFF8BCA84) : Colors.black,
                              width: isSelected ? 4 : 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13),
                                      ),
                                      child: Image.network(
                                        coverUrl,
                                        fit: BoxFit.cover,
                                        headers: const {
                                          "ngrok-skip-browser-warning": "69420",
                                        },
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFFDE047),
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.black87,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF8BCA84),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                  ],
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
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                      );
                    },
                  ),
          ),
          if (_selectedStoryIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Row(
                children: [
                  const Text(
                    "Phase: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        "Pre-test",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      value: "pre_test",
                      groupValue: _selectedTestType,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setState(() => _selectedTestType = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        "Post-test",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      value: "post_test",
                      groupValue: _selectedTestType,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setState(() => _selectedTestType = val!),
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedStoryIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF940D0D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isAssigning ? null : _assignSelectedStories,
                  child: _isAssigning
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Assign Selected Stories (${_selectedStoryIds.length})",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: ALERTS TAB (NEW) - TEACHER INTERVENTION
// ==========================================
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

      // ⚠️ TATAWAGIN ANG LARAVEL API MO DITO
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
