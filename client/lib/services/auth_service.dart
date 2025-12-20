import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String baseUrl = 'https://smartdhaka.onrender.com';
  //static const String baseUrl = 'http://localhost:3000';
  //static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator
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
    print(
        'Getting auth headers - Token: ${token != null ? 'Present' : 'Missing'}');
    if (token != null) {
      print('Token length: ${token.length}');
      print(
          'Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
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

  // Search user by friend code
  static Future<User?> searchUserByFriendCode(String friendCode) async {
    try {
      print('AuthService: Starting search for friend code: $friendCode');
      final headers = await getAuthHeaders();
      print('AuthService: Headers: $headers');

      final url = '$baseUrl/auth/search-friend/$friendCode';
      print('AuthService: Making request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('AuthService: Response status: ${response.statusCode}');
      print('AuthService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        print('AuthService: Parsed user data: $userData');
        final user = User.fromJson(userData);
        print('AuthService: Created user object: $user');
        return user;
      } else if (response.statusCode == 404) {
        print('AuthService: User not found (404)');
        return null;
      } else {
        print('AuthService: Unexpected status code: ${response.statusCode}');
        throw Exception('Failed to search user');
      }
    } catch (e) {
      print('AuthService: Error during search: $e');
      throw Exception('Search failed: $e');
    }
  }

  // Get current user's friend code
  static Future<String?> getCurrentUserFriendCode() async {
    try {
      print('AuthService: Getting current user friend code');
      final headers = await getAuthHeaders();
      print('AuthService: Headers: $headers');

      final url = '$baseUrl/auth/friend-code';
      print('AuthService: Making request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('AuthService: Response status: ${response.statusCode}');
      print('AuthService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('AuthService: Friend code: ${data['friendCode']}');
        return data['friendCode'];
      } else {
        print('AuthService: Failed to get friend code');
        return null;
      }
    } catch (e) {
      print('AuthService: Error getting friend code: $e');
      return null;
    }
  }

  // Send friend request
  static Future<bool> sendFriendRequest(String toUserId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-friend-request'),
        headers: headers,
        body: jsonEncode({'toUserId': toUserId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to send friend request');
      }
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  // Get pending friend requests
  static Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/pending-friend-requests'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['requests']);
      } else {
        throw Exception('Failed to get pending friend requests');
      }
    } catch (e) {
      throw Exception('Failed to get pending friend requests: $e');
    }
  }

  // Accept friend request
  static Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/accept-friend-request/$requestId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to accept friend request');
      }
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  // Reject friend request
  static Future<bool> rejectFriendRequest(String requestId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/reject-friend-request/$requestId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to reject friend request');
      }
    } catch (e) {
      throw Exception('Failed to reject friend request: $e');
    }
  }

  // Get friends list
  static Future<List<User>> getFriendsList() async {
    try {
      final headers = await getAuthHeaders();
      print('DEBUG: Getting friends list from: $baseUrl/auth/friends');
      final response = await http.get(
        Uri.parse('$baseUrl/auth/friends'),
        headers: headers,
      );

      print('DEBUG: Friends API response status: ${response.statusCode}');
      print('DEBUG: Friends API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG: Parsed friends data: $data');
        print('DEBUG: Friends data type: ${data.runtimeType}');
        print('DEBUG: Friends data keys: ${data is Map ? data.keys.toList() : 'not a map'}');
        
        // Handle different response structures
        List<Map<String, dynamic>> friendsListData = [];
        if (data is Map && data.containsKey('friends')) {
          friendsListData = List<Map<String, dynamic>>.from(data['friends']);
        } else if (data is List) {
          friendsListData = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          friendsListData = List<Map<String, dynamic>>.from(data['data']);
        }
        
        print('DEBUG: Extracted ${friendsListData.length} friends from response');
        
        final friends = friendsListData.map((friend) {
          print('DEBUG: Processing friend: $friend');
          // Ensure the friend has an id field (might be _id)
          if (friend.containsKey('_id') && !friend.containsKey('id')) {
            friend['id'] = friend['_id'].toString();
          }
          return User.fromJson(friend);
        }).toList();
        
        print('DEBUG: Created ${friends.length} User objects');
        return friends;
      } else {
        print('ERROR: Friends API returned status ${response.statusCode}');
        throw Exception('Failed to get friends list: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('ERROR: Exception in getFriendsList: $e');
      print('ERROR: Stack trace: $stackTrace');
      throw Exception('Failed to get friends list: $e');
    }
  }
}
