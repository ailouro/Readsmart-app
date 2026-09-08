import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String role;

  const ProfileSettingsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.role,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isUploading = false;
  String _avatarUrl = "";

  @override
  void initState() {
    super.initState();
    _loadSavedAvatar();
  }

  // I-load ang naka-save na avatar mula sa SharedPreferences
  Future<void> _loadSavedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarUrl = prefs.getString('user_avatar') ?? "";
    });
  }

  // Function para magbukas ng Gallery at mag-upload (WEB-SAFE)
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image == null) return; // Na-cancel ang pagpili

    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/users/${widget.userId}/avatar"),
      );

      // Idagdag ang mga headers (importante ang ngrok header)
      request.headers.addAll(networkHeaders);

      // FIX PARA SA FLUTTER WEB: Basahin as bytes imbes na file path
      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: image.name),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // I-save ang bagong avatar link sa phone
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', data['avatar_url']);

        setState(() {
          _avatarUrl = data['avatar_url'];
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture updated! 📸"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception(data['message'] ?? "Upload failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("error $e"),
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Linisin ang URL para sakto sa ngrok
    String displayUrl = _avatarUrl.startsWith('http')
        ? _avatarUrl
        : "$baseUrl$_avatarUrl";

    return Scaffold(
      backgroundColor: const Color(0xFFFDE047), // Comic Yellow
      appBar: AppBar(
        title: const Text(
          "Profile Settings",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFF940D0D),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF940D0D),
                            ),
                          )
                        : (_avatarUrl.isNotEmpty)
                        ? Image.network(
                            displayUrl,
                            fit: BoxFit.cover,
                            headers: const {
                              "ngrok-skip-browser-warning": "69420",
                            },
                            errorBuilder: (ctx, err, stack) => const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey,
                          ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF940D0D),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            Text(
              widget.role.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF940D0D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
