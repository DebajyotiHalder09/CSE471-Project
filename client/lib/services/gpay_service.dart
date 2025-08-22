import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class GpayService {
  static const String baseUrl = AuthService.baseUrl;

  static Future<Map<String, dynamic>> registerGpay() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gpay/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to register Gpay account');
      }
    } catch (e) {
      throw Exception('Failed to register Gpay account: $e');
    }
  }

  static Future<Map<String, dynamic>> loginGpay(String code) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gpay/login'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'code': code}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to login to Gpay');
      }
    } catch (e) {
      throw Exception('Failed to login to Gpay: $e');
    }
  }

  static Future<Map<String, dynamic>> getGpayBalance() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gpay/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get Gpay balance');
      }
    } catch (e) {
      throw Exception('Failed to get Gpay balance: $e');
    }
  }

  static Future<Map<String, dynamic>> rechargeWallet(double amount) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gpay/recharge'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to recharge wallet');
      }
    } catch (e) {
      throw Exception('Failed to recharge wallet: $e');
    }
  }

  static Future<Map<String, dynamic>> deductFromGpay(double amount) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gpay/deduct'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to deduct from Gpay');
      }
    } catch (e) {
      throw Exception('Failed to deduct from Gpay: $e');
    }
  }
}
