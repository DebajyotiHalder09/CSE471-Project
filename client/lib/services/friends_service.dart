import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FriendsService {
  static const String baseUrl = 'http://10.0.2.2:3000/api/friends';

  static Future<Map<String, dynamic>> getFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch friends: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error fetching friends: $e'};
    }
  }

  static Future<Map<String, dynamic>> addFriend(
      String userId, String friendCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
          'friendCode': friendCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to add friend: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error adding friend: $e'};
    }
  }
}
