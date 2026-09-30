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
          final history = (d['history'] as List);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                d['student_name'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(d['class_name']),
              const SizedBox(height: 16),
              const Text(
                'Reading Level History',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...history.map(
                (h) => ListTile(
                  leading: Icon(
                    Icons.circle,
                    color:
                        h['reading_level'].toString().toLowerCase() ==
                            'frustration'
                        ? Colors.red
                        : Colors.green,
                    size: 14,
                  ),
                  title: Text(h['reading_level'].toString()),
                  subtitle: Text(h['created_at'].toString().substring(0, 10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
