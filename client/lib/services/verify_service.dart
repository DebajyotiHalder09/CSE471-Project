import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class VerifyService {
  static Future<Map<String, dynamic>> uploadImage(String imageBase64) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/upload-image');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'image': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? 'Failed to upload image');
        } catch (_) {
          throw Exception('Failed to upload image. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> submitVerification({
    required String institutionName,
    required String institutionId,
    required String gmail,
    String? imageUrl,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/submit');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'institutionName': institutionName,
          'institutionId': institutionId,
          'gmail': gmail,
          'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to submit verification');
        } catch (_) {
          throw Exception('Failed to submit verification. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getMyVerification() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/my-status');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get verification status');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAllVerifications() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/all');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get verifications');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> approveVerification(String verificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/approve');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'verificationId': verificationId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to approve verification');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> rejectVerification(String verificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('${AuthService.baseUrl}/verify/reject');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'verificationId': verificationId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to reject verification');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

