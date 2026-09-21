import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Shows students an admin has assigned to this teacher but who are not
/// yet part of the teacher's class. The teacher decides, per student,
/// whether to Enroll them (adds to class roster) or Decline (sends the
/// student back to admin as unassigned).
class PendingEnrollmentTabView extends StatefulWidget {
  final int teacherId;
  final String baseUrl;

  const PendingEnrollmentTabView({
    Key? key,
    required this.teacherId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<PendingEnrollmentTabView> createState() =>
      _PendingEnrollmentTabViewState();
}

class _PendingEnrollmentTabViewState extends State<PendingEnrollmentTabView> {
  bool _isLoading = true;
  List<dynamic> _pending = [];
  final Set<int> _busyIds = {}; // student ids currently being enrolled/declined

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
          "${widget.baseUrl}/api/teachers/${widget.teacherId}/pending-students",
        ),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        _pending = decoded['data'] ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching pending students: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(int studentId, String action) async {
    setState(() => _busyIds.add(studentId));
    try {
      final res = await http.post(
        Uri.parse(
          "${widget.baseUrl}/api/teachers/${widget.teacherId}/students/$studentId/$action",
        ),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );
      if (res.statusCode == 200) {
        setState(() {
          _pending.removeWhere((s) => s['id'] == studentId);
        });
        if (mounted) {
          final decoded = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decoded['message'] ?? 'Done.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error responding to assignment: $e");
    } finally {
      if (mounted) setState(() => _busyIds.remove(studentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pending.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPending,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Walang naka-pending na estudyante.\nLahat ng assigned sa iyo ay na-enroll na.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
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
            "The admin assigned these students to you. Tap Enroll to add a student to your class, or Decline to send them back to the admin.",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPending,
            child: ListView.builder(
              itemCount: _pending.length,
              itemBuilder: (context, index) {
                final s = _pending[index];
                final int studentId = s['id'];
                final bool busy = _busyIds.contains(studentId);
                final String name = s['name'] ?? 'Unknown Student';
                final String grade = s['grade_level'] ?? '';
                final String section = s['section'] ?? '';
                final String lrn = s['lrn'] ?? 'N/A';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$grade • $section • LRN: $lrn'),
                    trailing: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _respond(studentId, 'decline'),
                                child: const Text('Decline'),
                              ),
                              ElevatedButton(
                                onPressed: () => _respond(studentId, 'enroll'),
                                child: const Text('Enroll'),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
