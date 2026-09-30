import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart';

class StudentAlertDetailScreen extends StatefulWidget {
  final int teacherId;
  final String studentId;
  const StudentAlertDetailScreen({
    super.key,
    required this.teacherId,
    required this.studentId,
  });

  @override
  State<StudentAlertDetailScreen> createState() =>
      _StudentAlertDetailScreenState();
}

class _StudentAlertDetailScreenState extends State<StudentAlertDetailScreen> {
  static const Color maroon = Color(0xFF940D0D);
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/api/teachers/${widget.teacherId}/alerts/${widget.studentId}',
        ),
        headers: networkHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          _data = jsonDecode(res.body)['data'];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Hindi ma-load: $e';
        _loading = false;
      });
    }
  }

  Widget _stat(String label, dynamic value, {String suffix = ''}) => Expanded(
    child: Column(
      children: [
        Text(
          value == null ? '—' : '$value$suffix',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Review'),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: maroon))
          : _error != null
          ? Center(child: Text(_error!))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final latest = d['latest'] as Map<String, dynamic>?;
    final words = (d['top_struggled_words'] as List?) ?? [];
    final history = (d['history'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${d['student_name'] ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text('${d['class_name'] ?? ''}'),
        const SizedBox(height: 16),
        if (latest != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Result',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat('Words/min', latest['wpm']),
                      _stat(
                        'Oral fluency',
                        latest['oral_fluency_accuracy'],
                        suffix: '%',
                      ),
                      _stat(
                        'Comprehension',
                        latest['comprehension_score_pct'],
                        suffix: '%',
                      ),
                      _stat(
                        'Word reading',
                        latest['word_reading_score_pct'],
                        suffix: '%',
                      ),
                    ],
                  ),
                  if (latest['reading_profile'] != null) ...[
                    const SizedBox(height: 10),
                    Text('Profile: ${latest['reading_profile']}'),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Words na nahirapan (most frequent)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (words.isEmpty)
          const Text('Wala pang naitalang struggled words.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: words
                .map(
                  (w) => Chip(
                    label: Text('${w['word']} (${w['count']}x)'),
                    backgroundColor: Colors.red.shade50,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 16),
        const Text(
          'Reading History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        ...history.map((h) {
          final isFrus = '${h['reading_level']}'.toLowerCase() == 'frustration';
          final quiz = (h['quiz_score'] != null && h['total_questions'] != null)
              ? ' • Quiz ${h['quiz_score']}/${h['total_questions']}'
              : '';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.circle,
              size: 14,
              color: isFrus ? Colors.red : Colors.green,
            ),
            title: Text('${h['story_title'] ?? h['test_type'] ?? 'Session'}'),
            subtitle: Text('${h['reading_level']} • ${h['date'] ?? ''}$quiz'),
          );
        }),
      ],
    );
  }
}
