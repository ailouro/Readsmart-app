import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TeacherReportsScreen extends StatefulWidget {
  final String baseUrl;
  final int teacherId;

  const TeacherReportsScreen({
    super.key,
    required this.baseUrl,
    required this.teacherId,
  });

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  List<dynamic> _mispronunciations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMispronunciationLogs();
  }

  Future<void> _fetchMispronunciationLogs() async {
    try {
      final url = Uri.parse(
        "${widget.baseUrl}/api/teachers/${widget.teacherId}/mispronunciations",
      );
      final response = await http.get(
        url,
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _mispronunciations = data['logs'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Reading Reports 📊"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mispronunciations.isEmpty
          ? const Center(
              child: Text(
                "No mispronunciation reports yet. Great job students! 🎉",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Text(
            "Words your students had trouble pronouncing while reading. Each card shows the student, the story and slide, the hard word, and the date.",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
                Expanded(
                  child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _mispronunciations.length,
              itemBuilder: (context, index) {
                final log = _mispronunciations[index];
                final studentName =
                    log['student']?['name'] ?? "Unknown Student";
                final storyTitle = log['story_title'] ?? "Story";
                final word = log['word'] ?? "N/A";
                final slideIndex = (log['slide_index'] ?? 0) + 1;
                final date =
                    log['created_at']?.toString().substring(0, 10) ?? "";

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(
                        Icons.record_voice_over,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📖 Story: $storyTitle (Slide $slideIndex)"),
                        Text(
                          "❌ Hard Word: \"$word\"",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
