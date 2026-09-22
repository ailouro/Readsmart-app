import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theapp/screens/story_view_screen.dart';
import '../services/config.dart';
import 'login_screen.dart';
import '../services/bgm_service.dart';
import 'class_dashboard_screen.dart';
import 'student_progress_screen.dart';
import '../widgets/bouncy_tap.dart';

// ==========================================
// 1. STUDENT DASHBOARD SCREEN
// ==========================================
class StudentDashboard extends StatefulWidget {
  final String userName;
  final int? studentId;

  const StudentDashboard({super.key, required this.userName, this.studentId});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with WidgetsBindingObserver {
  static const Color maroonTheme = Color(0xFF9B0505);
  static const Color accentTheme = Color(0xFFFDE047);
  static const Color cyanAccent = Color(0xFFAFE1EE);
  static const Color spideyBlue = Color(0xFF1D4ED8);
  static const Color paperColor = Color(0xFFFFF6E4);

  List<dynamic> _myClasses = [];
  bool _isLoading = true;
  int _selectedClassIndex = 0;
  // The student's own LRN, shown under their name so they (or a
  // teacher looking over their shoulder) can see what to log in with.
  // Read from whatever SharedPreferences key the login flow saved it
  // under; shown only when found so nothing breaks if it isn't.
  String? _lrn;
  // Tracks whether WE paused the bgm because the tab/app went out of
  // view, so we only resume it ourselves and don't fight with any
  // screen (e.g. a story) that intentionally stopped it for its own
  // narration audio.
  bool _bgmPausedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchMyClasses();
    _loadLrn();
    BgmService().startBgm();
  }

  List<dynamic> _myLibraryStories = [];
  bool _isLoadingLibrary = false;

  Future<void> _fetchMyLibrary() async {
    try {
      setState(() => _isLoadingLibrary = true);
      final studentId =
          await _getStudentId(); // Kunin ang ID ng nakalogin na estudyante
      if (studentId == null) return;

      final response = await http.get(
        Uri.parse("$baseUrl/api/student/$studentId/completed-stories"),
        headers:
            networkHeaders, // Siguraduhing kasama ang Authorization token kung kinakailangan
      );

      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        setState(() {
          // Depende sa JSON response mo, kunin ang 'data'
          _myLibraryStories = decoded['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching library: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLibrary = false);
    }
  }

  Future<void> _loadLrn() async {
    final prefs = await SharedPreferences.getInstance();
    final String? found =
        prefs.getString('lrn') ??
        prefs.getString('username') ??
        prefs.getString('user_lrn');
    if (mounted && found != null && found.isNotEmpty) {
      setState(() => _lrn = found);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pauses the background music when the browser tab (or app) is
  // switched away from / backgrounded, and resumes it when it's back
  // in view -- as long as we're the ones who paused it, and as long as
  // this dashboard is still the visible screen (not a story or class
  // screen pushed on top, which manage their own audio).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        BgmService().stopBgm();
        _bgmPausedByLifecycle = true;
        break;
      case AppLifecycleState.resumed:
        if (_bgmPausedByLifecycle &&
            mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          BgmService().startBgm();
        }
        _bgmPausedByLifecycle = false;
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<int?> _getStudentId() async {
    if (widget.studentId != null) return widget.studentId;
    final prefs = await SharedPreferences.getInstance();
    int? id =
        prefs.getInt('user_id') ??
        prefs.getInt('id') ??
        prefs.getInt('student_id');
    if (id == null) {
      String? stringId =
          prefs.getString('user_id') ??
          prefs.getString('id') ??
          prefs.getString('student_id');
      if (stringId != null) {
        id = int.tryParse(stringId);
      }
    }
    return id;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: const Text(
          "Time to Rest? 🏕️",
          style: TextStyle(fontWeight: FontWeight.w900, color: maroonTheme),
        ),
        content: const Text(
          "Are you ready to step away from your reading adventure?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Stay & Read",
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
            onPressed: () => Navigator.pop(context, true),
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
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _fetchMyClasses() async {
    try {
      setState(() => _isLoading = true);
      final studentId = await _getStudentId();
      if (studentId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final response = await http.get(
        Uri.parse("$baseUrl/api/student/$studentId/classes"),
        headers: networkHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        setState(() {
          var extractedData = decoded['data'] ?? decoded['classes'];
          _myClasses = (extractedData is List) ? extractedData : [];
          if (_selectedClassIndex >= _myClasses.length) {
            _selectedClassIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJoinClassDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: const Text(
          "Unlock a New Mission 🗝️",
          style: TextStyle(color: maroonTheme, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText: "Enter Secret Code",
            helperText: "Ask your teacher for the secret code.",
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            filled: true,
            fillColor: Colors.grey[100],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: maroonTheme, width: 3),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: maroonTheme,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _joinClass(codeController.text);
            },
            child: const Text(
              "Unlock Now!",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinClass(String classCode) async {
    if (classCode.trim().isEmpty) return;
    try {
      final studentId = await _getStudentId();
      if (studentId == null) return;
      final response = await http.post(
        Uri.parse("$baseUrl/api/student/join-class"),
        headers: {
          ...networkHeaders,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'class_code': classCode.trim(),
          'student_id': studentId,
        }),
      );
      final decoded = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New mission unlocked successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchMyClasses();
        BgmService().startBgm();
      }
    } catch (e) {
      debugPrint("Error joining class: $e");
    }
  }

  // Opens the currently selected class's story/mission list -- reuses the
  // same navigation as tapping a class card. Assumption: "Adventure Map"
  // means "browse this class's missions" -- point me elsewhere if not.
  Future<void> _openAdventureMap() async {
    if (_myClasses.isEmpty) {
      _showJoinClassDialog();
      return;
    }
    final currentStudentId = await _getStudentId();
    if (!mounted) return;

    final myClass =
        _myClasses[_selectedClassIndex.clamp(0, _myClasses.length - 1)];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassDashboardScreen(
          classId: (myClass['class_id'] ?? myClass['id']).toString(),
          className: myClass['name'] ?? myClass['section_name'] ?? 'Class',
          studentId: currentStudentId ?? 0,
        ),
      ),
    );
  }

  Future<void> _openProgress() async {
    final studentId = await _getStudentId();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProgressScreen(
          studentId: studentId ?? 0,
          baseUrl: baseUrl,
          studentName: widget.userName,
        ),
      ),
    );
  }

  Widget _buildAvatarIndicator(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentTheme,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: const Icon(Icons.person, color: Colors.black, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      _buildAvatarIndicator(45),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "HERO PROFILE",
                            style: TextStyle(
                              fontSize: 10,
                              color: accentTheme,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (_lrn != null)
                            Text(
                              "LRN: $_lrn",
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
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: accentTheme,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      tooltip: "My Trophies",
                      onPressed: _openProgress,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4)),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showJoinClassDialog,
            backgroundColor: accentTheme,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black, width: 3),
            ),
            elevation: 0,
            icon: const Icon(Icons.key_rounded, color: Colors.black, size: 24),
            label: const Text(
              "UNLOCK MISSION",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
      body: ComicBackground(
        child: RefreshIndicator(
          onRefresh: _fetchMyClasses,
          color: maroonTheme,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: _buildMissionsSection(),
          ),
        ),
      ),
    );

    // === DESKTOP LAYOUT: totoong sidebar + content na tabi-tabi,
    // walang black background at walang "phone-in-a-box" na nested Scaffold ===
    Widget desktopLayout = Scaffold(
      backgroundColor: paperColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: ComicBackground(
              child: RefreshIndicator(
                onRefresh: _fetchMyClasses,
                color: maroonTheme,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopTopBar(),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
                            child: _buildMissionsSection(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Self-contained breakpoint check -- no longer routed through the
    // separate ResponsiveLayout widget. Keying each branch forces Flutter to
    // fully dispose/remount when crossing the breakpoint (e.g. resizing a
    // desktop browser window) instead of trying to reuse render state
    // across two structurally different trees, which is a common source of
    // "it's there in the tree but nothing shows" bugs.
    return LayoutBuilder(
      key: const ValueKey('student_dashboard_root'),
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;
        return isDesktop
            ? KeyedSubtree(key: const ValueKey('desktop'), child: desktopLayout)
            : KeyedSubtree(key: const ValueKey('mobile'), child: mobileLayout);
      },
    );
  }

  // Shared na content ng "Your Missions" — ginagamit ng mobile AT desktop
  // layout, kaya iisa lang ang pinagmumulan ng UI (walang duplicate/black box).
  // Short "how to use this screen" note shown near the top of a section.
  Widget _buildInstructionNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderBanner(),
        const SizedBox(height: 25),
        _buildSectionTitle("🚀 YOUR MISSIONS"),
        const SizedBox(height: 10),
        _buildInstructionNote(
          "Tap your class below to open its stories. To join a new class, "
          "tap UNLOCK MISSION and type the secret code from your teacher.",
        ),
        const SizedBox(height: 15),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: maroonTheme),
            ),
          )
        else if (_myClasses.isEmpty)
          _buildEmptyState()
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClassTabs(),
              const SizedBox(height: 15),
              _buildClassCard(
                _myClasses[_selectedClassIndex.clamp(0, _myClasses.length - 1)],
              ),
            ],
          ),
      ],
    );
  }

  // Comic-sticker style na "tabs" — pill chips na may drop shadow/pressed
  // effect, awtomatikong nag-wa-wrap kaya hindi na sumasabit ang underline
  // sa mobile o desktop.
  Widget _buildClassTabs() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_myClasses.length, (i) {
        final c = _myClasses[i];
        final label = c['name'] ?? c['section_name'] ?? 'Class';
        final bool selected = i == _selectedClassIndex;
        return BouncyTap(
          onTap: () => setState(() => _selectedClassIndex = i),
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? maroonTheme : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(selected ? 1 : 3, selected ? 1 : 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }),
    );
  }

  // Desktop na header — malaki, malinaw, may sticker buttons sa halip
  // na paulit-ulit na icons gaya sa mobile app bar.
  Widget _buildDesktopTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WELCOME BACK, HERO",
                    style: TextStyle(
                      fontSize: 12,
                      color: maroonTheme,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  if (_lrn != null)
                    Text(
                      "LRN: $_lrn",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  _buildStickerButton(
                    icon: Icons.emoji_events_rounded,
                    color: accentTheme,
                    onTap: _openProgress,
                  ),
                  const SizedBox(width: 10),
                  _buildStickerButton(
                    icon: Icons.key_rounded,
                    color: Colors.white,
                    label: "UNLOCK MISSION",
                    onTap: _showJoinClassDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 18 : 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black, size: 20),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Sidebar ng desktop — solid maroon (walang grey/black wrapper), may
  // subtle web-line accent sa taas para sa "hero comic" na feel.
  Widget _buildSidebar() {
    // Deliberately a plain Container + Column, no Stack/CustomPaint overlay
    // on top of the content -- keeps this guaranteed to paint solidly even
    // if something else on the page misbehaves.
    return Container(
      width: 260,
      color: maroonTheme,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // School/app logo -- same circular badge treatment as the
            // teacher-side sidebar. Point this at your real asset path
            // (and add it under pubspec.yaml's assets: list).
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/sves_logo.jpg', fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            const Text(
              "READSMART HUB",
              style: TextStyle(
                fontSize: 13,
                color: accentTheme,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            _buildAvatarIndicator(72),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                widget.userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_lrn != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "LRN: $_lrn",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: Colors.white24, thickness: 1.2),
            ),
            const SizedBox(height: 8),
            _buildNavItem(
              Icons.emoji_events_rounded,
              "My Trophies",
              _openProgress,
            ),
            _buildNavItem(
              Icons.lock_reset_rounded,
              "Change Password",
              () async {
                final studentId = await _getStudentId();
                if (studentId != null && mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => ChangePasswordDialog(userId: studentId),
                  );
                }
              },
            ),
            _buildNavItem(
              Icons.map_rounded,
              "Adventure Map",
              _openAdventureMap,
            ),
            _buildNavItem(
              Icons.key_rounded,
              "Unlock Mission",
              _showJoinClassDialog,
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: Colors.white24, thickness: 1.2),
            ),
            _buildNavItem(
              Icons.logout_rounded,
              "Rest in Camp",
              _logout,
              danger: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 3.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))],
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
              Icons.rocket_launch_rounded,
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentTheme,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Text(
                    "CURRENT STATUS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Ready for an adventure, ${widget.userName}?",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        // Non-interactive label: white instead of button-yellow
        // (accentTheme) so it isn't mistaken for a tappable action.
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildClassCard(dynamic myClass) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
        right: 6,
        left: 6,
        top: 2,
      ), // Margin adjusted para pumasok sa loob ng TabView
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 3.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final currentStudentId = await _getStudentId();
            if (!mounted) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassDashboardScreen(
                  classId: (myClass['class_id'] ?? myClass['id']).toString(),
                  className:
                      myClass['name'] ?? myClass['section_name'] ?? 'Class',
                  studentId: currentStudentId ?? 0,
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
                    border: Border.all(color: Colors.black, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment
                        .center, // Igitna natin since fixed box height ito
                    children: [
                      Text(
                        myClass['name'] ??
                            myClass['section_name'] ??
                            'Story Zone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Text(
                          "Level ${myClass['grade_level'] ?? 'N/A'} Zone",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    border: Border.all(color: Colors.black, width: 2.5),
                  ),
                  child: const Text(
                    "PLAY",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontSize: 14,
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

  Widget _buildLibrarySection() {
    if (_isLoadingLibrary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myLibraryStories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Wala ka pang natatapos na kuwento. Tapusin ang mga missions para mapuno ang iyong Library! 📖",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myLibraryStories.length,
      itemBuilder: (context, index) {
        final story = _myLibraryStories[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.menu_book_rounded,
              color: Colors.amber,
              size: 36,
            ),
            title: Text(
              story['title'] ?? 'Kuwento',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Score: ${story['score'] ?? 'N/A'} • Tapos na basahin",
            ),
            trailing: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.green,
              size: 32,
            ),
            onTap: () {
              // I-open ang StoryViewer para sa re-reading
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(
                    story: story,
                    baseUrl: baseUrl,
                    studentId: widget.studentId ?? 0,
                    testType: "practice",
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 20),
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
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cyanAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 50,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Missions Found!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Ask your teacher for a secret code and tap 'Unlock Mission' below to begin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final int userId;

  const ChangePasswordDialog({super.key, required this.userId});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/user/change-password"),
        headers: {...networkHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'current_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      final decoded = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded['message'] ?? "Failed to change password."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black, width: 3.5),
      ),
      title: const Text(
        "Change Password 🔑",
        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF9B0505)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B0505),
          ),
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "Update Password",
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. POPUP PROFILE SETTINGS DIALOG
// ==========================================

// ==========================================
// 3. COMIC BACKGROUND & PAINTER
// ==========================================
class ComicBackground extends StatefulWidget {
  final Widget child;
  const ComicBackground({super.key, required this.child});

  @override
  State<ComicBackground> createState() => _ComicBackgroundState();
}

class _ComicBackgroundState extends State<ComicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    return ClipRect(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: EnhancedComicPainter(
                      rotation: _controller.value * 2 * pi,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(child: widget.child),
          ],
        ),
      ),
    );
  }
}

// Subtle spider-web accent — puro code (walang image), ginagamit bilang
// maliit na corner accent para sa "hero comic" na vibe.
class SpiderWebPainter extends CustomPainter {
  final Color color;
  SpiderWebPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = color.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final Offset center = Offset(size.width, 0);
    final double maxR = size.width > size.height ? size.width : size.height;

    const int strands = 6;
    for (int i = 0; i <= strands; i++) {
      final double angle = pi + (pi / 2) * (i / strands);
      final Offset end = Offset(
        center.dx + maxR * cos(angle),
        center.dy + maxR * sin(angle),
      );
      canvas.drawLine(center, end, linePaint);
    }

    for (int r = 1; r <= 4; r++) {
      final double radius = maxR * (r / 5);
      final Path arcPath = Path();
      bool first = true;
      for (double t = 0; t <= 1; t += 0.05) {
        final double angle = pi + (pi / 2) * t;
        final Offset p = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        if (first) {
          arcPath.moveTo(p.dx, p.dy);
          first = false;
        } else {
          arcPath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(arcPath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EnhancedComicPainter extends CustomPainter {
  final double rotation;
  EnhancedComicPainter({this.rotation = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.4);
    final Color rayColor1 = const Color(0xFFC7A2B2);
    final Color rayColor2 = const Color(0xFFB58B9E);
    final Paint rayPaint = Paint()..style = PaintingStyle.fill;

    const int totalRays = 24;
    final double angleStep = (2 * pi) / totalRays;
    final double maxRadius = max(size.width, size.height) * 1.8;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (int i = 0; i < totalRays; i++) {
      rayPaint.color = (i % 2 == 0) ? rayColor1 : rayColor2;
      final double startAngle = i * angleStep;
      final double endAngle = (i + 1) * angleStep;
      final rayPath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + maxRadius * cos(startAngle),
          center.dy + maxRadius * sin(startAngle),
        )
        ..lineTo(
          center.dx + maxRadius * cos(endAngle),
          center.dy + maxRadius * sin(endAngle),
        )
        ..close();
      canvas.drawPath(rayPath, rayPaint);
    }
    canvas.restore();

    final speedLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 36; i++) {
      final double angle = (i * 2 * pi) / 36;
      final Offset p1 = Offset(
        center.dx + cos(angle) * (size.width * 0.3),
        center.dy + sin(angle) * (size.height * 0.3),
      );
      final Offset p2 = Offset(
        center.dx + cos(angle) * maxRadius,
        center.dy + sin(angle) * maxRadius,
      );
      canvas.drawLine(p1, p2, speedLinePaint);
    }

    final dotPaint = Paint()..color = const Color(0x338E5A72);
    const double gridSpacing = 22.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      for (double y = 0; y < size.height; y += gridSpacing) {
        canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
      }
    }

    _drawStylizedCloud(canvas, Offset(size.width * 0.15, -15), scale: 0.95);
    _drawStylizedCloud(canvas, Offset(size.width * 0.85, 10), scale: 1.10);
    _drawStylizedCloud(
      canvas,
      Offset(size.width * 0.05, size.height + 15),
      scale: 1.15,
    );
    _drawStylizedCloud(
      canvas,
      Offset(size.width * 0.90, size.height + 5),
      scale: 1.0,
    );
    _draw3DStar(
      canvas,
      Offset(size.width * 0.88, size.height * 0.16),
      size: 18,
    );
    _draw3DStar(
      canvas,
      Offset(size.width * 0.78, size.height * 0.21),
      size: 12,
    );
    _draw3DStar(
      canvas,
      Offset(size.width * 0.10, size.height * 0.75),
      size: 16,
    );
    _draw3DLightning(canvas, Offset(size.width * 0.92, size.height * 0.32));
    _draw3DLightning(canvas, Offset(size.width * 0.06, size.height * 0.60));
    _drawComicBurst(
      canvas,
      Offset(size.width * 0.92, size.height * 0.78),
      scale: 0.8,
    );
  }

  void _drawStylizedCloud(Canvas canvas, Offset origin, {double scale = 1.0}) {
    final Path cloudPath = Path();
    cloudPath.moveTo(origin.dx - 60 * scale, origin.dy);
    cloudPath.cubicTo(
      origin.dx - 85 * scale,
      origin.dy - 30 * scale,
      origin.dx - 45 * scale,
      origin.dy - 65 * scale,
      origin.dx - 5 * scale,
      origin.dy - 45 * scale,
    );
    cloudPath.cubicTo(
      origin.dx + 15 * scale,
      origin.dy - 75 * scale,
      origin.dx + 70 * scale,
      origin.dy - 55 * scale,
      origin.dx + 65 * scale,
      origin.dy - 20 * scale,
    );
    cloudPath.cubicTo(
      origin.dx + 95 * scale,
      origin.dy - 10 * scale,
      origin.dx + 85 * scale,
      origin.dy + 35 * scale,
      origin.dx + 50 * scale,
      origin.dy + 35 * scale,
    );
    cloudPath.cubicTo(
      origin.dx + 20 * scale,
      origin.dy + 50 * scale,
      origin.dx - 50 * scale,
      origin.dy + 45 * scale,
      origin.dx - 60 * scale,
      origin.dy,
    );
    cloudPath.close();

    final Matrix4 shadowMatrix = Matrix4.identity()..translate(4.0, 4.0);
    final Path shadowPath = cloudPath.transform(shadowMatrix.storage);

    final Paint strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(shadowPath, Paint()..color = Colors.black);
    canvas.drawPath(cloudPath, Paint()..color = const Color(0xFFAFE1EE));
    canvas.drawPath(
      Path()..addOval(
        Rect.fromCircle(
          center: Offset(origin.dx - 10 * scale, origin.dy - 20 * scale),
          radius: 22 * scale,
        ),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(cloudPath, strokePaint);
  }

  void _draw3DStar(Canvas canvas, Offset center, {required double size}) {
    final Path starPath = Path();
    for (int i = 0; i < 5; i++) {
      double angle = (i * 4 * pi) / 5 - pi / 2;
      double x = center.dx + cos(angle) * size;
      double y = center.dy + sin(angle) * size;
      if (i == 0)
        starPath.moveTo(x, y);
      else
        starPath.lineTo(x, y);
    }
    starPath.close();
    canvas.drawPath(
      starPath.transform(Matrix4.translationValues(3, 3, 0).storage),
      Paint()..color = Colors.black,
    );
    canvas.drawPath(starPath, Paint()..color = const Color(0xFFFDE047));
    canvas.drawPath(
      starPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _draw3DLightning(Canvas canvas, Offset center) {
    final Path boltPath = Path()
      ..moveTo(center.dx, center.dy - 24)
      ..lineTo(center.dx - 14, center.dy + 4)
      ..lineTo(center.dx - 2, center.dy + 4)
      ..lineTo(center.dx - 10, center.dy + 28)
      ..lineTo(center.dx + 16, center.dy - 4)
      ..lineTo(center.dx + 4, center.dy - 4)
      ..close();
    canvas.drawPath(
      boltPath.transform(Matrix4.translationValues(3, 3, 0).storage),
      Paint()..color = Colors.black,
    );
    canvas.drawPath(boltPath, Paint()..color = const Color(0xFFFDE047));
    canvas.drawPath(
      boltPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawComicBurst(Canvas canvas, Offset center, {double scale = 1.0}) {
    final Path burstPath = Path();
    for (int i = 0; i < 12; i++) {
      final double angle = (i * 2 * pi) / 12;
      final double radius = (i % 2 == 0) ? 25 * scale : 12 * scale;
      final double x = center.dx + cos(angle) * radius;
      final double y = center.dy + sin(angle) * radius;
      if (i == 0)
        burstPath.moveTo(x, y);
      else
        burstPath.lineTo(x, y);
    }
    burstPath.close();
    canvas.drawPath(
      burstPath.transform(Matrix4.translationValues(3, 3, 0).storage),
      Paint()..color = Colors.black,
    );
    canvas.drawPath(burstPath, Paint()..color = const Color(0xFFFF5252));
    canvas.drawPath(
      burstPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
