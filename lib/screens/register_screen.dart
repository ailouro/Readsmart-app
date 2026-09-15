import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'teacher';
  bool _isLoading = false;

  // Which required fields failed validation on the last submit attempt —
  // drives the red border on each field until the person fixes it.
  Set<String> _fieldErrors = {};
  // Tracks which password-type fields are currently showing plain text
  // instead of dots, keyed by the same fieldKey used for error tracking.
  final Set<String> _visiblePasswordFields = {};

  static const primaryColor = Color(0xFF940D0D);
  static const secondaryColor = Color(0xFFFDE047);

  // Above this width we switch from the stacked mobile layout to the
  // split-screen desktop layout.
  static const double _desktopBreakpoint = 900;

  Future<void> _register() async {
    final Set<String> errors = {};
    if (_firstNameController.text.trim().isEmpty) errors.add('firstName');
    if (_lastNameController.text.trim().isEmpty) errors.add('lastName');
    if (_loginController.text.trim().isEmpty) errors.add('login');
    if (_passwordController.text.isEmpty) errors.add('password');
    if (_confirmPasswordController.text.isEmpty) {
      errors.add('confirmPassword');
    }

    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _fieldErrors = {'password', 'confirmPassword'});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() {
      _fieldErrors = {};
      _isLoading = true;
    });

    final String fullName =
        "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}"
            .trim();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/register"),
        headers: {
          ...networkHeaders,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': fullName,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'login': _loginController.text,
          'password': _passwordController.text,
          'password_confirmation': _confirmPasswordController.text,
          'role': _selectedRole,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        String successMsg = _selectedRole == 'student'
            ? "Account created successfully! You may now login."
            : "Account created! A verification link was sent to your email. Please verify it before logging in.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorData['message'] ?? "Registration failed. Try again.",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not connect to online server: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildComicTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    String? fieldKey,
  }) {
    final bool hasError = fieldKey != null && _fieldErrors.contains(fieldKey);
    final Color borderColor = hasError ? Colors.red.shade700 : Colors.black;
    final bool isVisible =
        fieldKey != null && _visiblePasswordFields.contains(fieldKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 3.5),
        boxShadow: [BoxShadow(color: borderColor, offset: const Offset(4, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        onChanged: fieldKey == null
            ? null
            : (_) {
                if (_fieldErrors.contains(fieldKey)) {
                  setState(() => _fieldErrors.remove(fieldKey));
                }
              },
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(icon, color: Colors.black),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black54,
                  ),
                  onPressed: fieldKey == null
                      ? null
                      : () {
                          setState(() {
                            if (isVisible) {
                              _visiblePasswordFields.remove(fieldKey);
                            } else {
                              _visiblePasswordFields.add(fieldKey);
                            }
                          });
                        },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared pieces reused by both layouts
  // ---------------------------------------------------------------------

  Widget _buildLogo({double size = 85}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/sves_logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTitleBlock({required Color taglineColor, double fontSize = 32}) {
    return Column(
      children: [
        Stack(
          children: [
            Text(
              "CREATE ACCOUNT",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6
                  ..color = Colors.black,
              ),
            ),
            Text(
              "CREATE ACCOUNT",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "Join ReadSmart today!",
          style: TextStyle(
            color: taglineColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton({required Color iconColor, required Color bgColor}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3)),
          ],
        ),
        child: Icon(Icons.arrow_back_rounded, color: iconColor),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 3.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 32),
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.school_outlined, color: Colors.black),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        items: const [
          DropdownMenuItem(value: 'teacher', child: Text("Teacher")),
          DropdownMenuItem(value: 'parent', child: Text("Parent")),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedRole = value);
          }
        },
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildComicTextField(
          controller: _firstNameController,
          hintText: "First Name",
          icon: Icons.badge_outlined,
          fieldKey: 'firstName',
        ),
        const SizedBox(height: 20),

        _buildComicTextField(
          controller: _lastNameController,
          hintText: "Last Name",
          icon: Icons.badge_outlined,
          fieldKey: 'lastName',
        ),
        const SizedBox(height: 20),

        _buildComicTextField(
          controller: _loginController,
          hintText: "Email or LRN",
          icon: Icons.email_outlined,
          fieldKey: 'login',
        ),
        const SizedBox(height: 20),

        _buildRoleDropdown(),
        const SizedBox(height: 20),

        _buildComicTextField(
          controller: _passwordController,
          hintText: "Password",
          icon: Icons.lock_outline,
          isPassword: true,
          fieldKey: 'password',
        ),
        const SizedBox(height: 20),

        _buildComicTextField(
          controller: _confirmPasswordController,
          hintText: "Confirm Password",
          icon: Icons.lock_reset_outlined,
          isPassword: true,
          fieldKey: 'confirmPassword',
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.black, width: 4),
                ),
                elevation: 0,
              ).copyWith(elevation: WidgetStateProperty.all(0)),
              child: const Text(
                "SIGN UP",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
                ),
              ),
            ),
          );
  }

  // ---------------------------------------------------------------------
  // MOBILE — single column, stacked top to bottom (original layout)
  // ---------------------------------------------------------------------

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 32),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 20),
              _buildTitleBlock(taglineColor: Colors.black87),
              const SizedBox(height: 30),
              _buildFormFields(),
              const SizedBox(height: 40),
              _buildSignUpButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DESKTOP — split screen: branding panel + form panel
  // ---------------------------------------------------------------------

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: secondaryColor,
      body: Row(
        children: [
          // Left: branding / illustration panel
          Expanded(
            flex: 5,
            child: Container(
              height: double.infinity,
              color: primaryColor,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Decorative comic-style bursts, kept behind everything.
                  Positioned(
                    top: -70,
                    right: -70,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secondaryColor.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -90,
                    left: -50,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _buildBackButton(
                      iconColor: Colors.black,
                      bgColor: Colors.white,
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogo(size: 110),
                          const SizedBox(height: 28),
                          _buildTitleBlock(
                            taglineColor: secondaryColor,
                            fontSize: 36,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_stories_rounded,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    "Turn every lesson into an adventure.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
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
                  ),
                ],
              ),
            ),
          ),

          // Right: the form, in a floating comic-styled card
          Expanded(
            flex: 6,
            child: Container(
              color: secondaryColor,
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 48,
                  horizontal: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Let's get you set up",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Fill in your details below to get started",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildFormFields(),
                        const SizedBox(height: 32),
                        _buildSignUpButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }
}
