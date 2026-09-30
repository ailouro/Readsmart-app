import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class StudentAlertDetailScreen extends StatelessWidget {
  final String teacherId;
  final String studentId;
  const StudentAlertDetailScreen({
    Key? key,
    required this.teacherId,
    required this.studentId,
  }) : super(key: key);

  Widget _stat(String label, dynamic value, {String suffix = ''}) {
    return Expanded(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Review')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: AlertService().getAlertDetail(teacherId, studentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(child: Text('Error loading student'));
          }

          final d = snap.data!;
          final latest = d['latest'] as Map<String, dynamic>?;
          final words = (d['top_struggled_words'] as List?) ?? [];
          final history = (d['history'] as List?) ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                d['student_name'] ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(d['class_name'] ?? ''),
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
                final isFrus =
                    h['reading_level'].toString().toLowerCase() ==
                    'frustration';
                final quiz =
                    (h['quiz_score'] != null && h['total_questions'] != null)
                    ? ' • Quiz ${h['quiz_score']}/${h['total_questions']}'
                    : '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: isFrus ? Colors.red : Colors.green,
                  ),
                  title: Text(h['story_title'] ?? h['test_type'] ?? 'Session'),
                  subtitle: Text(
                    '${h['reading_level']} • ${h['date'] ?? ''}$quiz',
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
