import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:theapp/services/config.dart'; // Kung may base_url ka dito

class AlertService {
  // Palitan ng actual backend URL/IP mo
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  Future<List<dynamic>> getTeacherAlerts(String teacherId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/$teacherId/alerts'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']; // Depende sa structure na binalik ng Laravel
      } else {
        throw Exception('Failed to load alerts');
      }
    } catch (e) {
      print('Error fetching alerts: $e');
      return [];
    }
  }
}
