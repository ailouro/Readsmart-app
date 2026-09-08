import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class AuthService {
  // Replace with your IP from the previous step
  final String baseUrl = "http://10.104.218.92:8000/api";

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login"),
        headers: networkHeaders,
        body: jsonEncode({
          // Gamitin ang variable mula sa parameter ng function
          'email':
              identifier, // o 'login' kung iyon ang hinihingi ng Laravel mo
          'password':
              password, // Siguraduhing may 'String password' parameter ang function mo
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body); // Success! Returns user data
      } else {
        return {'error': 'Invalid credentials'};
      }
    } catch (e) {
      return {'error': 'Could not connect to server'};
    }
  }
}
