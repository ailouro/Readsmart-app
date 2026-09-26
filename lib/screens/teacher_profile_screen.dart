import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart';
import 'login_screen.dart';
import '../widgets/guide_comic_background.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final dynamic teacherId;

  const TeacherProfileScreen({
    super.key,
    required this.userName,
    this.userEmail = "teacher@school.edu",
    this.teacherId,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  static const Color maroonTheme = Color.fromARGB(255, 155, 5, 5);

  late String _currentName;
  late String _currentEmail;

  // Para sa profile picture
  Uint8List? _imageBytes;
  bool _isUploadingImage = false;

  // Para sa change password
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _currentEmail = widget.userEmail;
    _loadProfileData();
    _fetchLatestEmailFromServer();
  }

  // Kukunin ang naitagong profile info at image sa SharedPreferences
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase64Image = prefs.getString('user_profile_base64');

    if (!mounted) return;
    setState(() {
      _currentName = prefs.getString('user_name') ?? widget.userName;
      _currentEmail = prefs.getString('user_email') ?? widget.userEmail;
      if (savedBase64Image != null && savedBase64Image.isNotEmpty) {
        _imageBytes = base64Decode(savedBase64Image);
      }
    });
  }

  // 📧 Kunin ang TOTOONG registered email ng teacher mula sa backend,
  // hindi lang yung locally-cached/placeholder value. Silent refresh ito:
  // ipapakita muna yung naka-cache (o default) habang kinukuha ito sa likod,
  // tapos ia-update lang yung UI kapag may nakuhang tunay na email.
  //
  // NOTE: i-adjust yung endpoint path ("/api/teachers/{id}") at yung mga key
  // na sinusubukang basahin (email / teacher.email / data.email / user.email)
  // kung iba ang actual na route o response shape ng Laravel backend mo.
  Future<void> _fetchLatestEmailFromServer() async {
    if (widget.teacherId == null) return;

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/teachers/${widget.teacherId}"),
        headers: networkHeaders,
      );

      if (response.statusCode != 200) {
        debugPrint(
          "Could not fetch teacher email (status ${response.statusCode})",
        );
        return;
      }

      final data = jsonDecode(response.body);
      final String? serverEmail =
          (data['email'] ??
                  data['teacher']?['email'] ??
                  data['data']?['email'] ??
                  data['user']?['email'])
              ?.toString();

      if (serverEmail == null || serverEmail.trim().isEmpty) return;
      if (!mounted) return;

      setState(() => _currentEmail = serverEmail.trim());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', serverEmail.trim());
    } catch (e) {
      debugPrint("Could not refresh teacher email from server: $e");
    }
  }

  // 📷 PICK AND SAVE IMAGE FUNCTION
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();

    // Dialog para pumili kung Camera o Gallery
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Change Profile Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: maroonTheme,
              ),
              title: const Text("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: maroonTheme),
              title: const Text("Take a Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    final Uint8List bytes = await pickedFile.readAsBytes();
    final String base64Image = base64Encode(bytes);

    // Save locally para mag-persist agad sa UI at offline
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_base64', base64Image);

    // Subukang i-upload sa Laravel Backend (kung may API endpoint na)
    await _uploadImageToBackend(pickedFile);

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _isUploadingImage = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile picture updated successfully!")),
    );
  }

  // 🌐 BACKEND UPLOAD (OPTIONAL API INTEGRATION)
  Future<void> _uploadImageToBackend(XFile imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/user/upload-avatar"),
      );
      request.headers.addAll(networkHeaders);

      final bytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: imageFile.name),
      );

      await request.send();
    } catch (e) {
      debugPrint("Backend image upload skipped/failed: $e");
    }
  }

  // 🚪 LOGOUT FUNCTION
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: maroonTheme),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_profile_base64');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ✏️ EDIT PROFILE DIALOG
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentName);
    final emailController = TextEditingController(text: _currentEmail);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Edit Profile Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: maroonTheme),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person_outline, color: maroonTheme),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email_outlined, color: maroonTheme),
                  helperText:
                      "This is tied to your login account and can't be changed here.",
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: maroonTheme),
              onPressed: () async {
                final newName = nameController.text.trim();

                if (newName.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', newName);

                  if (!mounted) return;

                  setState(() {
                    _currentName = newName;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Profile updated successfully!"),
                    ),
                  );
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 🔒 CHANGE PASSWORD DIALOG
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true, obscureNew = true, obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Change Password",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: maroonTheme,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPassController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: "Current Password",
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: maroonTheme,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureCurrent = !obscureCurrent,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? "Enter your current password"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPassController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: "New Password",
                          prefixIcon: const Icon(
                            Icons.lock_reset,
                            color: maroonTheme,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Enter a new password";
                          }
                          if (v.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPassController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Confirm New Password",
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: maroonTheme,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v != newPassController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isChangingPassword
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: maroonTheme),
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => _isChangingPassword = true);
                          setState(() => _isChangingPassword = true);

                          final error = await _submitPasswordChange(
                            currentPassword: currentPassController.text,
                            newPassword: newPassController.text,
                          );

                          setDialogState(() => _isChangingPassword = false);
                          if (mounted) {
                            setState(() => _isChangingPassword = false);
                          }

                          if (!mounted) return;

                          if (error == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Password changed successfully!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  child: _isChangingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Update",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Submits the password change to the backend. Returns null on success, or
  // a user-facing error message on failure (e.g. wrong current password).
  //
  // NOTE: i-adjust yung endpoint path at yung mga field name kung iba ang
  // ginamit ng Laravel route/controller mo (hal. "old_password" imbes na
  // "current_password", o "password"/"password_confirmation" imbes na
  // "new_password"/"new_password_confirmation" — karaniwang default ng
  // Laravel 'confirmed' validation rule ay "{field}_confirmation").
  Future<String?> _submitPasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (widget.teacherId == null) {
      return "Missing teacher account info. Please log in again.";
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/teachers/${widget.teacherId}/change-password"),
        headers: {...networkHeaders, "Content-Type": "application/json"},
        body: jsonEncode({
          "current_password": currentPassword,
          "new_password": newPassword,
          "new_password_confirmation": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      }

      // Try to surface the backend's own error message (e.g. Laravel
      // validation errors or a "current password incorrect" message).
      try {
        final data = jsonDecode(response.body);
        final msg =
            data['message'] ??
            (data['errors'] != null
                ? (data['errors'] as Map).values.first[0]
                : null);
        return msg?.toString() ?? "Failed to change password.";
      } catch (_) {
        return "Failed to change password (${response.statusCode}).";
      }
    } catch (e) {
      debugPrint("Change password error: $e");
      return "Something went wrong. Please check your connection.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Make scaffold transparent
      body: GuideComicBackground(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. TOP MAROON HEADER WITH EDITABLE AVATAR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, bottom: 30),
                child: Column(
                  children: [
                    // PROFILE IMAGE WITH CAMERA EDIT BUTTON
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFFF5E6E6),
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : null,
                            child: _imageBytes == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 60,
                                    color: maroonTheme,
                                  )
                                : null,
                          ),
                        ),
                        // Camera Icon Button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingImage
                                ? null
                                : _pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 3,
                                ),
                              ),
                              child: _isUploadingImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _currentName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: maroonTheme,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                      child: const Text(
                        "Teacher / Educator",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 2. INFORMATION CARD & ACTIONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(5, 5)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.person_outline_rounded,
                              title: "Full Name",
                              value: _currentName,
                            ),
                            const Divider(
                              height: 24,
                              color: Colors.black,
                              thickness: 1.5,
                            ),
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              title: "Email",
                              value: _currentEmail,
                            ),
                            const Divider(
                              height: 24,
                              color: Colors.black,
                              thickness: 1.5,
                            ),
                            _buildInfoRow(
                              icon: Icons.school_outlined,
                              title: "Role",
                              value: "Reading Educator",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: maroonTheme,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(
                          "Edit Profile Details",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _showEditProfileDialog,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: maroonTheme,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text(
                          "Change Password",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _showChangePasswordDialog,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: maroonTheme,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          "Log Out",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: maroonTheme.withOpacity(0.1),
          child: Icon(icon, color: maroonTheme, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
