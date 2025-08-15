import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip_history.dart';
import 'auth_service.dart';

class TripHistoryService {
  static const String baseUrl = AuthService.baseUrl;

  static Future<Map<String, dynamic>> addTrip({
    required String busId,
    required String busName,
    required double distance,
    required double fare,
    required String source,
    required String destination,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final uri = Uri.parse('$baseUrl/trip/add');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': busId,
          'busName': busName,
          'distance': distance,
          'fare': fare,
          'source': source,
          'destination': destination,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to add trip'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUserTrips() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final uri = Uri.parse('$baseUrl/trip/user');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<TripHistory> trips = (data['data'] as List<dynamic>)
            .map((trip) => TripHistory.fromJson(trip))
            .toList();
        return {'success': true, 'data': trips};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to fetch trips'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
