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

  const TeacherProfileScreen({
    super.key,
    required this.userName,
    this.userEmail = "teacher@school.edu",
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

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _currentEmail = widget.userEmail;
    _loadProfileData();
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
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email_outlined, color: maroonTheme),
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
                final newEmail = emailController.text.trim();

                if (newName.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', newName);
                  await prefs.setString('user_email', newEmail);

                  if (!mounted) return;

                  setState(() {
                    _currentName = newName;
                    _currentEmail = newEmail;
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
