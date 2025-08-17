import 'dart:convert';
import 'dart:convert' show utf8, base64Url;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// Global callback for wallet updates
typedef WalletUpdateCallback = void Function(double balance, int gems);

class WalletService {
  static WalletUpdateCallback? _onWalletUpdate;

  static void setWalletUpdateCallback(WalletUpdateCallback? callback) {
    _onWalletUpdate = callback;
  }

  static void notifyWalletUpdate(double balance, int gems) {
    _onWalletUpdate?.call(balance, gems);
  }

  static Future<Map<String, dynamic>> getWalletBalance() async {
    try {
      print('WalletService: Getting token...');
      final token = await AuthService.getToken();
      if (token == null) {
        print('WalletService: No token found');
        return {
          'success': false,
          'message': 'Authentication required',
          'balance': 0.0,
        };
      }

      print('WalletService: Token found: ${token.substring(0, 20)}...');

      // Decode the JWT token to see the user ID
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final payloadMap = json.decode(resp);
          print('WalletService: JWT payload: $payloadMap');
          print('WalletService: User ID from JWT: ${payloadMap['id']}');
        }
      } catch (e) {
        print('WalletService: Could not decode JWT: $e');
      }

      print('WalletService: Token found, calling API...');
      final uri = Uri.parse('${AuthService.baseUrl}/wallet/balance');
      print('WalletService: API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('WalletService: Response status: ${response.statusCode}');
      print('WalletService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('WalletService: Parsed data: $data');
        final balance = (data['balance'] ?? 0.0).toDouble();
        final gems = (data['gems'] ?? 0).toInt();
        print('WalletService: Extracted balance: $balance, gems: $gems');
        return {
          'success': true,
          'balance': balance,
          'gems': gems,
          'message': data['message'] ?? 'Wallet balance retrieved successfully',
        };
      } else if (response.statusCode == 404) {
        print('WalletService: Wallet not found, returning 0 balance');
        return {
          'success': true,
          'balance': 0.0,
          'message': 'Wallet not found, creating new wallet',
        };
      } else {
        print('WalletService: API error: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch wallet balance',
          'balance': 0.0,
        };
      }
    } catch (e) {
      print('WalletService: Exception: $e');
      return {
        'success': false,
        'message': 'Error fetching wallet balance: $e',
        'balance': 0.0,
      };
    }
  }

  static Future<Map<String, dynamic>> testWalletAPI() async {
    try {
      print('WalletService: Testing wallet API...');
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No token found',
        };
      }

      final uri = Uri.parse('${AuthService.baseUrl}/wallet/test');
      print('WalletService: Test API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('WalletService: Test response status: ${response.statusCode}');
      print('WalletService: Test response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Test failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('WalletService: Test exception: $e');
      return {
        'success': false,
        'message': 'Test error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> initializeAllWallets() async {
    try {
      print('WalletService: Initializing all user wallets...');
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No token found',
        };
      }

      final uri = Uri.parse('${AuthService.baseUrl}/wallet/initialize-all');
      print('WalletService: Initialize wallets API URL: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'WalletService: Initialize response status: ${response.statusCode}');
      print('WalletService: Initialize response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Initialize failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('WalletService: Initialize exception: $e');
      return {
        'success': false,
        'message': 'Initialize error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> refreshWalletData() async {
    try {
      print('WalletService: Refreshing wallet data...');
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No token found',
        };
      }

      final uri = Uri.parse('${AuthService.baseUrl}/wallet/balance');
      print('WalletService: Refresh wallet API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('WalletService: Refresh response status: ${response.statusCode}');
      print('WalletService: Refresh response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final balance = (data['balance'] ?? 0.0).toDouble();
        final gems = (data['gems'] ?? 0).toInt();
        print('WalletService: Refreshed balance: $balance, gems: $gems');

        // Notify listeners of wallet update
        notifyWalletUpdate(balance, gems);

        return {
          'success': true,
          'balance': balance,
          'gems': gems,
          'message': 'Wallet data refreshed successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to refresh wallet data',
          'balance': 0.0,
          'gems': 0,
        };
      }
    } catch (e) {
      print('WalletService: Refresh exception: $e');
      return {
        'success': false,
        'message': 'Error refreshing wallet data: $e',
        'balance': 0.0,
        'gems': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> convertGemsToBalance() async {
    try {
      print('WalletService: Converting gems to balance...');
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No token found',
        };
      }

      final uri = Uri.parse('${AuthService.baseUrl}/wallet/convert-gems');
      print('WalletService: Convert gems API URL: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'WalletService: Convert gems response status: ${response.statusCode}');
      print('WalletService: Convert gems response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final balance = (data['balance'] ?? 0.0).toDouble();
        final gems = (data['gems'] ?? 0).toInt();
        final convertedAmount = (data['convertedAmount'] ?? 0.0).toDouble();
        final gemsUsed = (data['gemsUsed'] ?? 0).toInt();

        print('WalletService: Converted $gemsUsed gems to ৳$convertedAmount');

        // Notify listeners of wallet update
        notifyWalletUpdate(balance, gems);

        return {
          'success': true,
          'balance': balance,
          'gems': gems,
          'convertedAmount': convertedAmount,
          'gemsUsed': gemsUsed,
          'message': data['message'] ?? 'Gems converted successfully',
        };
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to convert gems',
          'balance': 0.0,
          'gems': 0,
        };
      }
    } catch (e) {
      print('WalletService: Convert gems exception: $e');
      return {
        'success': false,
        'message': 'Error converting gems: $e',
        'balance': 0.0,
        'gems': 0,
      };
    }
  }
}
