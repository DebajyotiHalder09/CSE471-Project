import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:3000'; // For iOS simulator
  // static const String baseUrl = 'http://192.168.1.2:3000'; // For physical device

  // Token storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Store token
  static Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Store user data
  static Future<void> storeUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Get stored user
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Clear stored data (logout)
  static Future<void> clearStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Get auth headers with token
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    print('Getting auth headers - Token: ${token != null ? 'Present' : 'Missing'}');
    if (token != null) {
      print('Token length: ${token.length}');
      print('Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }
    
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    
    print('Final headers: $headers');
    return headers;
  }

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

        // Store token and user data
        await storeToken(responseData['token']);
        await storeUser(User.fromJson(responseData['user']));

        return responseData;
      } else {
        throw Exception(
            jsonDecode(response.body)['error'] ?? 'Failed to login');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<void> signup(String name, String email, String gender, String role,
      String password) async {
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

  // Validate token with server
  Future<bool> validateToken() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/validate'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await clearStoredData();
  }

  // Update user profile
  Future<void> updateProfile(Map<String, dynamic> updateData) async {
    try {
      final headers = await getAuthHeaders();
      print('Sending profile update request to: $baseUrl/auth/profile');
      print('Headers: $headers');
      print('Update data: $updateData');

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: headers,
        body: jsonEncode(updateData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('Profile update error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update user password
  Future<void> updatePassword(
      String currentPassword, String newPassword) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update password');
      }
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }
}
