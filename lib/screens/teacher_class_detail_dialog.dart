import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart'; // Adjust import to your config file path
import 'story_view_screen.dart';

class TeacherClassDetailScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String gradeLevel;

  const TeacherClassDetailScreen({
    super.key,
    required this.classId,
    required this.className,
    this.gradeLevel = 'Grade 5',
  });

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _assignedStories = [];
  List<dynamic> _students = [];

  static const Color maroonTheme = Color(0xFF800000);
  static const Color yellowAccent = Color(0xFFFFE047);

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  // --- API FETCH: Class Data (Stories & Students) ---
  Future<void> _fetchClassData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/classes/${widget.classId}"),
        headers: networkHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        setState(() {
          _assignedStories = data['assigned_stories'] ?? data['stories'] ?? [];
          _students = data['students'] ?? data['enrolled_students'] ?? [];
        });
      }

      // Fallback for students endpoint if array was empty
      if (_students.isEmpty) {
        final studentRes = await http.get(
          Uri.parse("$baseUrl/api/classes/${widget.classId}/students"),
          headers: networkHeaders,
        );
        if (studentRes.statusCode == 200) {
          final decoded = jsonDecode(studentRes.body);
          setState(() {
            _students = decoded is List
                ? decoded
                : (decoded['data'] ?? decoded['students'] ?? []);
          });
        }
      }

      // Fallback for stories endpoint if array was empty
      if (_assignedStories.isEmpty) {
        final storyRes = await http.get(
          Uri.parse("$baseUrl/api/classes/${widget.classId}/stories"),
          headers: networkHeaders,
        );
        if (storyRes.statusCode == 200) {
          final decoded = jsonDecode(storyRes.body);
          setState(() {
            _assignedStories = decoded is List
                ? decoded
                : (decoded['stories'] ?? decoded['data'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching class details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTION: Assign Story Modal ---
  void _openAssignStoryModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignStorySheet(
        classId: widget.classId,
        onStoryAssigned: _fetchClassData,
      ),
    );
  }

  // --- ACTION: Delete Class ---
  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Class?"),
        content: Text(
          "Are you sure you want to delete '${widget.className}'? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

      try {
      final res = await http.delete(
        Uri.parse("$baseUrl/api/classes/${widget.classId}"),
        headers: networkHeaders,
      );

      if ((res.statusCode == 200 || res.statusCode == 204) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Class deleted successfully")),
        );
        Navigator.pop(context, true); // Close screen & notify dashboard
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete. Code: ${res.statusCode}, Body: ${res.body}"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Error deleting class: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: maroonTheme,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.className,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                widget.gradeLevel,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            // --- SETTINGS / OPTIONAL ACTIONS MENU ---
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings),
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
                      Text("Delete Class", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: yellowAccent,
            indicatorWeight: 4,
            labelColor: yellowAccent,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: "Stories"),
              Tab(icon: Icon(Icons.people), text: "Students"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: maroonTheme))
            : TabBarView(children: [_buildStoriesTab(), _buildStudentsTab()]),
      ),
    );
  }

  // --- TAB 1: STORIES TAB ---
  Widget _buildStoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Assign Story Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: yellowAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Assign Story to this Class",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _openAssignStoryModal,
            ),
          ),
          const SizedBox(height: 16),

          // Assigned Stories Grid/List
          Expanded(
            child: _assignedStories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No stories assigned to this class yet.",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _assignedStories.length,
                    itemBuilder: (context, index) {
                      final story = _assignedStories[index];
                      final title = story['title'] ?? 'Untitled';
                      final pagesCount = (story['pages'] as List?)?.length ?? 0;
                      final cover =
                          story['cover_image'] ?? story['thumbnail'] ?? '';

                      return GestureDetector(
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  child: cover.isNotEmpty
                                      ? Image.network(
                                          "$baseUrl/api/get-image?path=$cover",
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _placeholderCover(),
                                        )
                                      : _placeholderCover(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "$pagesCount Pages",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: STUDENTS TAB ---
  Widget _buildStudentsTab() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              "No students have joined this class yet.",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final name = student['name'] ?? student['username'] ?? 'Student';
        final email = student['email'] ?? 'No email provided';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 1.5),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: yellowAccent,
              child: Icon(Icons.person, color: Colors.black),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(email),
            trailing: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderCover() {
    return Container(
      color: Colors.amber[100],
      child: const Center(
        child: Icon(Icons.menu_book, size: 36, color: Colors.amber),
      ),
    );
  }
}

// --- MODAL: SELECT & ASSIGN TEACHER STORIES ---
class _AssignStorySheet extends StatefulWidget {
  final String classId;
  final VoidCallback onStoryAssigned;

  const _AssignStorySheet({
    required this.classId,
    required this.onStoryAssigned,
  });

  @override
  State<_AssignStorySheet> createState() => _AssignStorySheetState();
}

class _AssignStorySheetState extends State<_AssignStorySheet> {
  bool _loading = true;
  List<dynamic> _myLibraryStories = [];

  @override
  void initState() {
    super.initState();
    _fetchLibraryStories();
  }

  Future<void> _fetchLibraryStories() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/stories"),
        headers: networkHeaders,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() {
          _myLibraryStories = decoded is List
              ? decoded
              : (decoded['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching teacher library: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignStory(dynamic storyId) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/classes/${widget.classId}/assign-story"),
        headers: networkHeaders,
        body: jsonEncode({"story_id": storyId}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        widget.onStoryAssigned();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error assigning story: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Story to Assign",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _myLibraryStories.isEmpty
                ? const Center(
                    child: Text("No uploaded stories found in library."),
                  )
                : ListView.builder(
                    itemCount: _myLibraryStories.length,
                    itemBuilder: (context, index) {
                      final story = _myLibraryStories[index];
                      return ListTile(
                        title: Text(story['title'] ?? 'Untitled'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE047),
                          ),
                          onPressed: () => _assignStory(story['id']),
                          child: const Text(
                            "Assign",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
