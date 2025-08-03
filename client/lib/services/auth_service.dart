import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://192.168.1.2:3000'; // For Android emulator
// or 'http://localhost:3000' for web 192.168.1.2 'http://10.0.2.2:3000'

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Login response: $responseData'); // Add debug print
        return responseData;
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to login');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<void> signup(String name, String email, String gender, String role, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'gender': gender,
        'role': role,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to signup');
    }
  }
}