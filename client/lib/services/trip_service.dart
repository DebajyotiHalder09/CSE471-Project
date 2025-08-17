import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_service.dart';

class TripService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<Map<String, dynamic>> completeBusTrip({
    required String busId,
    required String busName,
    required double distance,
    required double fare,
    required String source,
    required String destination,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/trip'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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

        // Refresh wallet data to get updated gems count
        try {
          await WalletService.refreshWalletData();
        } catch (e) {
          print('Error refreshing wallet data: $e');
        }

        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to complete trip: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error completing trip: $e'};
    }
  }

  static Future<Map<String, dynamic>> completeRideshareTrip({
    required String postId,
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/rideshare/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'postId': postId,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Refresh wallet data to get updated gems count
        try {
          await WalletService.refreshWalletData();
        } catch (e) {
          print('Error refreshing wallet data: $e');
        }

        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to complete rideshare trip: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error completing rideshare trip: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> getUserTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/trip'),
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
          'message': 'Failed to fetch trips: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error fetching trips: $e'};
    }
  }
}
