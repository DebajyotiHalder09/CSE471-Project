import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class BusService {
  static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:3000'; // For iOS simulator

  static Future<Map<String, dynamic>> getAllBuses() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bus/all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get buses');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search bus by name
  static Future<Map<String, dynamic>> searchBusByName(String busName) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bus/search-by-name?busName=$busName'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to search bus');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search bus by route
  static Future<Map<String, dynamic>> searchBusByRoute(
      String startLocation, String endLocation) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse(
            '$baseUrl/bus/search-by-route?startLocation=$startLocation&endLocation=$endLocation'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to search route');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
