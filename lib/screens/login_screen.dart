import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theapp/screens/teacher_dashboard.dart';
import 'package:theapp/screens/student_dashboard.dart';
import 'package:theapp/screens/parent_dashboard_screen.dart';
import 'register_screen.dart';
import '../services/config.dart';
import '../services/bgm_service.dart';

// 🎨 COMIC POP-ART BACKGROUND CUSTOM PAINTER
class ComicBackground extends StatelessWidget {
  final Widget child;
  const ComicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ComicBackgroundPainter(), child: child);
  }
}

class _ComicBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF8CE3FB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFEAA1AC)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double stepX = 48.0;
    const double stepY = 48.0;

    for (double x = 0; x < size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dotPaint = Paint()..color = const Color(0xFFF1D84A);
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        if (i + j < 10) {
          canvas.drawCircle(
            Offset(size.width - (i * 18.0), (j * 18.0) + 40),
            3.5,
            dotPaint,
          );
          canvas.drawCircle(
            Offset((i * 18.0) + 40, size.height - (j * 18.0)),
            3.5,
            dotPaint,
          );
        }
      }
    }

    final yellowPaint = Paint()..color = const Color(0xFFEED353);
    final blackOutline = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final whitePaint = Paint()..color = Colors.white;

    final trPath = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(trPath, yellowPaint);

    final trLightning = Path()
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.78, 25)
      ..lineTo(size.width * 0.72, 110)
      ..lineTo(size.width * 0.88, 70)
      ..lineTo(size.width, 160)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(trLightning, whitePaint);
    canvas.drawPath(trLightning, blackOutline);

    final blPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(blPath, yellowPaint);

    final blLightning = Path()
      ..moveTo(0, size.height * 0.84)
      ..lineTo(size.width * 0.12, size.height * 0.82)
      ..lineTo(size.width * 0.27, size.height * 0.88)
      ..lineTo(size.width * 0.18, size.height * 0.95)
      ..lineTo(size.width * 0.35, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(blLightning, whitePaint);
    canvas.drawPath(blLightning, blackOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureLoginPassword = true;

  bool _isLoading = false;
  bool _rememberMe = false;
  // Which portal is selected: 'student', 'teacher', or 'parent'. Replaces
  // the old two-way _isStudentLogin bool now that Teacher and Parent have
  // their own separate login boxes instead of sharing one "Teacher / Parent"
  // tab.
  String _loginRole = 'student';

  // --- VARIABLES PARA SA REQUEST ACCOUNT FORM ---
  final _reqFirstNameController = TextEditingController();
  final _reqLastNameController = TextEditingController();
  final _reqLrnController = TextEditingController();
  final _reqSectionController = TextEditingController();
  final _reqParentEmailController = TextEditingController();
  String _reqGradeLevel = 'Grade 5'; // Default grade
  bool _isRequestingAccount = false;

  // Which required fields failed validation on the last submit attempt in
  // the Request Account dialog — drives the red border until fixed.
  Set<String> _reqFieldErrors = {};

  @override
  void initState() {
    super.initState();
    BgmService().startBgm();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedToken = prefs.getString('auth_token');
    final String? savedRole = prefs.getString('user_role');
    final String? savedName = prefs.getString('user_name');
    final int? savedId = prefs.getInt('user_id') ?? prefs.getInt('id');
    final bool savedRememberMe = prefs.getBool('remember_me') ?? false;

    if (savedToken != null &&
        savedRole != null &&
        savedName != null &&
        mounted) {
      final String cleanRole = savedRole.trim().toLowerCase();
      if (cleanRole == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDashboard(userName: savedName),
          ),
        );
      } else if (cleanRole == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StudentDashboard(userName: savedName, studentId: savedId),
          ),
        );
      } else if (cleanRole == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ParentDashboardScreen(
              baseUrl: baseUrl,
              parentId: savedId?.toString() ?? '',
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _rememberMe = savedRememberMe;
          if (savedRememberMe) {
            _loginController.text = prefs.getString('saved_login') ?? '';
            _passwordController.text = prefs.getString('saved_password') ?? '';
          }
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_loginController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all fields."),
          backgroundColor: Colors.green,
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
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login"),
        headers: networkHeaders,
        body: jsonEncode({
          'login': _loginController.text,
          'password': _passwordController.text,
        }),
      );

      final decodedData = jsonDecode(response.body);

      // --- HANDLING UNVERIFIED EMAILS (403) ---
      if (response.statusCode == 403 &&
          decodedData['needs_verification'] == true) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.black, width: 3),
            ),
            title: const Text(
              "Verification Required 📧",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF9B0505),
              ),
            ),
            content: Text(
              decodedData['message'] ??
                  "Please verify your email address to continue.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B0505),
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Sending email..."),
                      backgroundColor: Colors.green,
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
                  await http.post(
                    Uri.parse("$baseUrl/api/email/resend"),
                    headers: networkHeaders,
                    body: jsonEncode({'email': decodedData['email']}),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Verification link resent! Check your inbox.",
                      ),
                      backgroundColor: Colors.green,
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
                },
                child: const Text(
                  "Resend Email",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      // --- NORMAL LOGIN PROCESS (200) ---
      if (response.statusCode == 200) {
        final data = decodedData;
        final Map<String, dynamic>? userData =
            data['user'] is Map<String, dynamic> ? data['user'] : null;
        final String name =
            userData?['name']?.toString() ?? data['name']?.toString() ?? 'User';
        final String token =
            data['token']?.toString() ?? 'session_token_placeholder';
        final dynamic rawId =
            userData?['id'] ??
            data['id'] ??
            userData?['user_id'] ??
            data['user_id'];

        int? userId;
        if (rawId is int)
          userId = rawId;
        else if (rawId != null)
          userId = int.tryParse(rawId.toString());

        final String role =
            (userData?['role']?.toString() ??
                    data['role']?.toString() ??
                    'teacher')
                .trim()
                .toLowerCase();

        // Account mismatch: the account's real role must match whichever
        // portal box (Student / Teacher / Parent) was used to log in.
        if (role != _loginRole) {
          setState(() => _isLoading = false);
          const roleLabels = {
            'student': 'Student',
            'teacher': 'Teacher',
            'parent': 'Parent',
          };
          final actualLabel = roleLabels[role] ?? 'a different';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Account mismatch! This is a $actualLabel account — please use the $actualLabel tab.",
              ),
              backgroundColor: Colors.green,
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

        final prefs = await SharedPreferences.getInstance();

        if (userId != null) {
          await prefs.setInt('user_id', userId);
          await prefs.setInt('id', userId);
        }

        if (_rememberMe) {
          await prefs.setString('saved_login', _loginController.text);
          await prefs.setString('saved_password', _passwordController.text);
        } else {
          await prefs.remove('saved_login');
          await prefs.remove('saved_password');
        }
        await prefs.setBool('remember_me', _rememberMe);

        // 🛠️ FIX: The session itself (auth_token/user_role/user_name) used
        // to be saved ONLY when "Remember me" was checked, and actively
        // REMOVED otherwise. That meant an unchecked "Remember me" wiped
        // the session on every login — so refreshing the page (which
        // re-runs _checkSavedSession from scratch) always found nothing
        // and bounced back to the login screen, even though login had
        // just succeeded. "Remember me" should only control whether the
        // login/password fields get pre-filled next time, not whether the
        // current session survives a page refresh — so the token/role/name
        // are now always saved here, independent of that checkbox.
        await prefs.setString('auth_token', token);
        await prefs.setString('user_role', role);
        await prefs.setString('user_name', name);

        if (!mounted) return;

        if (role == 'teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TeacherDashboard(userName: name)),
          );
        } else if (role == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StudentDashboard(userName: name, studentId: userId),
            ),
          );
        } else if (role == 'parent') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentDashboardScreen(
                baseUrl: baseUrl,
                parentId: userId?.toString() ?? '',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid credentials. Please try again."),
            backgroundColor: Colors.green,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not connect to online server: $e"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // 📝 ACCOUNT REQUEST API CALL & DIALOG
  // ============================================================================
  Future<void> _submitAccountRequest(StateSetter setDialogState) async {
    final Set<String> errors = {};
    if (_reqFirstNameController.text.trim().isEmpty) {
      errors.add('firstName');
    }
    if (_reqLastNameController.text.trim().isEmpty) errors.add('lastName');
    if (_reqLrnController.text.trim().isEmpty) errors.add('lrn');
    if (_reqSectionController.text.trim().isEmpty) errors.add('section');
    if (_reqParentEmailController.text.trim().isEmpty) {
      errors.add('parentEmail');
    }

    if (errors.isNotEmpty) {
      setDialogState(() => _reqFieldErrors = errors);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all details."),
          backgroundColor: Colors.green,
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

    setDialogState(() {
      _reqFieldErrors = {};
      _isRequestingAccount = true;
    });

    final String fullStudentName =
        "${_reqFirstNameController.text.trim()} ${_reqLastNameController.text.trim()}"
            .trim();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/request-student-account"),
        headers: {
          ...networkHeaders,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'student_name': fullStudentName,
          'first_name': _reqFirstNameController.text.trim(),
          'last_name': _reqLastNameController.text.trim(),
          'lrn': _reqLrnController.text.trim(),
          'grade_level': _reqGradeLevel,
          'section': _reqSectionController.text.trim(),
          'parent_email': _reqParentEmailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context); // Isara ang dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Request submitted!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Linisin ang form para sa susunod
        _reqFirstNameController.clear();
        _reqLastNameController.clear();
        _reqLrnController.clear();
        _reqSectionController.clear();
        _reqParentEmailController.clear();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Request failed."),
            backgroundColor: Colors.green,
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
          content: Text("Connection error: $e"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setDialogState(() => _isRequestingAccount = false);
    }
  }

  void _showRequestAccountDialog() {
    _reqFieldErrors = {};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDE047),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.black, width: 4),
              ),
              title: const Text(
                "REQUEST ACCOUNT 🎒",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Make sure your Parent has registered an account using their email before you request here!",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9B0505),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      _reqFirstNameController,
                      "First Name",
                      Icons.badge,
                      fieldKey: 'firstName',
                      setDialogState: setDialogState,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      _reqLastNameController,
                      "Last Name",
                      Icons.badge,
                      fieldKey: 'lastName',
                      setDialogState: setDialogState,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      _reqLrnController,
                      "LRN (12 Digits)",
                      Icons.pin,
                      fieldKey: 'lrn',
                      setDialogState: setDialogState,
                    ),
                    const SizedBox(height: 12),

                    // Grade Level Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _reqGradeLevel,
                          isExpanded: true,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          items: ['Grade 5', 'Grade 6'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => _reqGradeLevel = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      _reqSectionController,
                      "Section",
                      Icons.class_,
                      fieldKey: 'section',
                      setDialogState: setDialogState,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      _reqParentEmailController,
                      "Parent's Registered Email",
                      Icons.email,
                      fieldKey: 'parentEmail',
                      setDialogState: setDialogState,
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: _isRequestingAccount
                      ? null
                      : () => Navigator.pop(context),
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
                    backgroundColor: const Color(0xFF9B0505),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  onPressed: _isRequestingAccount
                      ? null
                      : () => _submitAccountRequest(setDialogState),
                  child: _isRequestingAccount
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Submit Request",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showForgotPasswordDialog(BuildContext context) {
    final identifierController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 3.5),
          ),
          title: const Text(
            "Forgot Password 🔒",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF9B0505),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your LRN or registered Username/Email to request a reset.",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: identifierController,
                decoration: InputDecoration(
                  labelText: "LRN / Username",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B0505),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final text = identifierController.text.trim();
                      if (text.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        final response = await http.post(
                          Uri.parse("$baseUrl/api/forgot-password"),
                          headers: {
                            ...networkHeaders,
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({'identifier': text}),
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Password reset link or temporary credentials have been sent.",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error requesting reset: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted)
                          setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Submit", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    String? fieldKey,
    StateSetter? setDialogState,
  }) {
    final bool hasError =
        fieldKey != null && _reqFieldErrors.contains(fieldKey);
    final Color errorColor = Colors.red.shade700;

    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.bold),
      onChanged: (fieldKey == null || setDialogState == null)
          ? null
          : (_) {
              if (_reqFieldErrors.contains(fieldKey)) {
                setDialogState(() => _reqFieldErrors.remove(fieldKey));
              }
            },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? errorColor : Colors.black,
            width: hasError ? 2.5 : 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? errorColor : const Color(0xFF9B0505),
            width: 2.5,
          ),
        ),
      ),
    );
  }
  // ============================================================================

  Widget _buildLogoAndTitle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 3.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4)),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/sves_logo.jpg',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Stack(
          children: [
            Text(
              "ReadSmart",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6
                  ..color = Colors.black,
              ),
            ),
            const Text(
              "ReadSmart",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFF9B0505),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: const Text(
            "Enhancing Literacy through Tech",
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTab({
    required String role,
    required String emoji,
    required String label,
    required Color activeColor,
    required Color activeTextColor,
  }) {
    final bool isActive = _loginRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _loginRole = role;
            _loginController.clear();
            _passwordController.clear();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              "$emoji $label",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: isActive ? activeTextColor : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // TABS: Student / Teacher / Parent — three separate login boxes,
        // each routing to the matching backend role check above.
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            children: [
              _buildRoleTab(
                role: 'student',
                emoji: '👨\u200d🎓',
                label: 'Student',
                activeColor: const Color(0xFFFDE047),
                activeTextColor: Colors.black,
              ),
              _buildRoleTab(
                role: 'teacher',
                emoji: '👩\u200d🏫',
                label: 'Teacher',
                activeColor: const Color(0xFF9B0505),
                activeTextColor: Colors.white,
              ),
              _buildRoleTab(
                role: 'parent',
                emoji: '👪',
                label: 'Parent',
                activeColor: const Color(0xFF0F766E),
                activeTextColor: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FORM CONTAINER
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 3.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(5, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (_loginRole) {
                  'teacher' => "Teacher Portal",
                  'parent' => "Parent Portal",
                  _ => "Student Portal",
                },
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _loginController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _loginRole == 'student'
                      ? "Enter your LRN"
                      : "Email Address",
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  prefixIcon: Icon(
                    _loginRole == 'student'
                        ? Icons.badge_outlined
                        : Icons.email_outlined,
                    color: const Color(0xFF9B0505),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAF6F6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF9B0505),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                obscureText: _obscureLoginPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF9B0505)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureLoginPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.black54,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureLoginPassword = !_obscureLoginPassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAF6F6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF9B0505),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _rememberMe = !_rememberMe);
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            activeColor: const Color(0xFF9B0505),
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Remember me",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showForgotPasswordDialog(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Forgot password?",
                        style: TextStyle(
                          color: Color(0xFF9B0505),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // LOGIN BUTTON
        _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF9B0505))
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B0505),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: Colors.black, width: 3),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "LOGIN",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 20),

        // DYNAMIC BOTTOM TEXT — differs per portal:
        //  - Student: "Request Account" dialog (existing flow, unchanged)
        //  - Teacher: teachers self-register, so "Sign Up" -> RegisterScreen
        //  - Parent: nothing in the backend lets a parent self-register —
        //    AdminWebController only ever creates parent accounts via admin
        //    bulk-import, or approveStudentRequest() which explicitly
        //    REQUIRES an existing parent account to already exist. So no
        //    "Sign Up" button is shown here; if RegisterScreen actually does
        //    support a parent role (I haven't seen that file to confirm),
        //    swap this back to the Sign Up button.
        switch (_loginRole) {
          'student' => Column(
            children: [
              const Text(
                "Don't have an account?",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showRequestAccountDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE047),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                  child: const Text(
                    "Request Account",
                    style: TextStyle(
                      color: Color(0xFF9B0505),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          'teacher' => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE047),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      color: Color(0xFF9B0505),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _ => const Text(
            "Don't have an account? Ask your child's teacher or the\n"
            "school admin to set one up for you.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        },
        const SizedBox(height: 50),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: ComicBackground(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          child: SingleChildScrollView(
            child: screenWidth >= 800
                ? SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: _buildLogoAndTitle(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: screenWidth * 0.1,
                              left: 20,
                              top: 40,
                              bottom: 40,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 450,
                                ),
                                child: _buildFormContent(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 100),
                        _buildLogoAndTitle(),
                        const SizedBox(height: 40),
                        _buildFormContent(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
