import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FavBusService {
  static const String baseUrl = 'https://smartdhaka.onrender.com';
  //static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator

  static Future<Map<String, dynamic>> addToFavorites({
    required String userId,
    required String busId,
    required String busName,
    String? routeNumber,
    String? operator,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/favbus/add'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'busId': busId,
          'busName': busName,
          'routeNumber': routeNumber,
          'operator': operator,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to add to favorites');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> removeFromFavorites({
    required String userId,
    required String busId,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/favbus/remove'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'busId': busId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to remove from favorites');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserFavorites(String userId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/favbus/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get favorites');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> checkIfFavorited({
    required String userId,
    required String busId,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/favbus/check?userId=$userId&busId=$busId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to check favorite status');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
