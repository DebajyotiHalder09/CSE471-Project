import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class FareService {
  static const String baseUrl = AuthService.baseUrl;

  // Save fare data
  static Future<Map<String, dynamic>> saveFare({
    required String userId,
    required String source,
    required String destination,
    required double distance,
    Map<String, double>? sourceCoordinates,
    Map<String, double>? destinationCoordinates,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/fares'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'source': source,
          'destination': destination,
          'distance': distance,
          if (sourceCoordinates != null) 'sourceCoordinates': sourceCoordinates,
          if (destinationCoordinates != null) 'destinationCoordinates': destinationCoordinates,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to save fare: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get fare for a route
  static Future<Map<String, dynamic>> getFare({
    String? userId,
    required String source,
    required String destination,
  }) async {
    try {
      final queryParams = <String, String>{
        'source': source,
        'destination': destination,
      };
      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final uri = Uri.parse('$baseUrl/api/fares').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Fare not found',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get fare: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get all fares for a user
  static Future<Map<String, dynamic>> getUserFares(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/fares/user/$userId'),
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
          'message': 'Failed to get user fares: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Calculate road distance using backend (OSRM)
  static Future<Map<String, dynamic>> calculateRoadDistance({
    required double sourceLat,
    required double sourceLon,
    required double destLat,
    required double destLon,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/geocoding/distance').replace(
        queryParameters: {
          'sourceLat': sourceLat.toString(),
          'sourceLon': sourceLon.toString(),
          'destLat': destLat.toString(),
          'destLon': destLon.toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Distance calculation timed out', const Duration(seconds: 15));
        },
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
          'message': 'Failed to calculate distance: ${response.statusCode}',
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

