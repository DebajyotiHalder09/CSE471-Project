import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class RideRequestService {
  static const String baseUrl = AuthService.baseUrl;

  static Future<Map<String, dynamic>> sendRideRequest({
    required String ridePostId,
    required String requesterId,
    required String requesterName,
    required String requesterGender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/riderequests/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ridePostId': ridePostId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'requesterGender': requesterGender,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Failed to send ride request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sending ride request: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getRideRequests(String ridePostId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/riderequests/ride/$ridePostId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Failed to get ride requests',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting ride requests: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> acceptRideRequest({
    required String requestId,
    required String ridePostId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/riderequests/accept/$requestId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ridePostId': ridePostId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Failed to accept ride request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error accepting ride request: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> rejectRideRequest(String requestId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/riderequests/reject/$requestId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Failed to reject ride request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error rejecting ride request: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getUserRequests(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/riderequests/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Failed to get user requests',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting user requests: $e',
      };
    }
  }
}
