import 'dart:convert';
import 'package:http/http.dart' as http;

class RideshareService {
  //static const String baseUrl = 'https://smartdhaka0.onrender.com';
  static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator

  static Future<Map<String, dynamic>> createRidePost({
    required String source,
    required String destination,
    required String userId,
    required String userName,
    required String gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/rideshare'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'source': source,
          'destination': destination,
          'userId': userId,
          'userName': userName,
          'gender': gender,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['ridePost'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create ride post: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getAllRidePosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rideshare'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch ride posts: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getUserRides(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rideshare/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch user rides: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteRidePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/rideshare/$postId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Failed to delete ride post: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
