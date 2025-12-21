import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class NotificationService {
  static const String baseUrl = AuthService.baseUrl;

  // Get all notifications for a user
  static Future<Map<String, dynamic>> getUserNotifications({
    String? userId,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      if (userId == null) {
        final user = await AuthService.getUser();
        userId = user?.id;
      }

      if (userId == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      final uri = Uri.parse('$baseUrl/api/notifications/user/$userId').replace(
        queryParameters: {
          'limit': limit.toString(),
          'unreadOnly': unreadOnly.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get notifications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get unread notification count
  static Future<Map<String, dynamic>> getUnreadCount({String? userId}) async {
    try {
      if (userId == null) {
        final user = await AuthService.getUser();
        userId = user?.id;
      }

      if (userId == null) {
        return {
          'success': false,
          'count': 0,
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'count': 0,
      };
    }
  }

  // Mark notification as read
  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/notifications/read/$notificationId'),
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
          'message': 'Failed to mark as read: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Mark all notifications as read
  static Future<Map<String, dynamic>> markAllAsRead({String? userId}) async {
    try {
      if (userId == null) {
        final user = await AuthService.getUser();
        userId = user?.id;
      }

      if (userId == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/api/notifications/read-all'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to mark all as read: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete notification
  static Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/$notificationId'),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete notification: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete all notifications
  static Future<Map<String, dynamic>> deleteAllNotifications({String? userId}) async {
    try {
      if (userId == null) {
        final user = await AuthService.getUser();
        userId = user?.id;
      }

      if (userId == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/user/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete all notifications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Create SOS notification for all users
  static Future<Map<String, dynamic>> createSOSNotification({
    required String userId,
    required String userName,
    required String source,
    double? latitude,
    double? longitude,
    String? serviceType,
    String? serviceName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/sos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userName': userName,
          'source': source,
          'latitude': latitude,
          'longitude': longitude,
          'serviceType': serviceType,
          'serviceName': serviceName,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
          'message': data['message'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create SOS notification',
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

