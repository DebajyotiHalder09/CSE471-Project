import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class RatingService {
  static const String baseUrl = AuthService.baseUrl;

  // Get rating for a specific bus
  static Future<Map<String, dynamic>> getBusRating(String busId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/bus/$busId'),
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
          'message': 'Failed to get bus rating: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get all bus ratings
  static Future<Map<String, dynamic>> getAllBusRatings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/all'),
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
          'message': 'Failed to get all bus ratings: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Submit a rating for a bus
  static Future<Map<String, dynamic>> submitRating({
    required String busId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'busId': busId,
          'userId': userId,
          'rating': rating,
          'comment': comment ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to submit rating',
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

