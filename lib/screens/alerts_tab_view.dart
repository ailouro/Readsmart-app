import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class AlertsTabView extends StatefulWidget {
  final String teacherId;
  const AlertsTabView({Key? key, required this.teacherId}) : super(key: key);

  @override
  _AlertsTabViewState createState() => _AlertsTabViewState();
}

class _AlertsTabViewState extends State<AlertsTabView> {
  final AlertService _alertService = AlertService();
  late Future<List<dynamic>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _alertService.getTeacherAlerts(widget.teacherId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _alertsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading alerts'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Hooray! Walang student sa Frustration level.'),
          );
        }

        final alerts = snapshot.data!;

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
            "These students are reading at the Frustration level and may need extra help.",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
            Expanded(
              child: ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
                title: Text(
                  alert['student_name'] ?? 'Unknown Student',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(alert['reason'] ?? 'Needs intervention'),
                trailing: ElevatedButton(
                  onPressed: () {
                    // Logic para i-message ang bata, o i-view ang full profile
                  },
                  child: const Text('Action'),
                ),
              ),
            );
          },
              ),
            ),
          ],
        );
      },
    );
  }
}
