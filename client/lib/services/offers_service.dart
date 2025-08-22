import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offers.dart';

class OffersService {
  static const String baseUrl = 'http://10.0.2.2:3000/offers';
  static const String authUrl = 'http://10.0.2.2:3000/auth';

  static Future<Offers> getUserOffers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('DEBUG: Parsed JSON data: $jsonData');
        print('DEBUG: Data type: ${jsonData.runtimeType}');

        if (jsonData is Map<String, dynamic>) {
          print('DEBUG: Keys in data: ${jsonData.keys.toList()}');
          print('DEBUG: walletId type: ${jsonData['walletId']?.runtimeType}');
          print('DEBUG: userId type: ${jsonData['userId']?.runtimeType}');
        }

        return Offers.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load offers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Error in getUserOffers: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FormatException) {
        print('DEBUG: Format error details: ${e.message}');
        print('DEBUG: Format error source: ${e.source}');
        print('DEBUG: Format error offset: ${e.offset}');
      }
      throw Exception('Failed to load offers: $e');
    }
  }

  static Future<Offers> updateUserOffers(
    String token,
    double cashback,
    double coupon,
    double discount,
    bool isActive,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'cashback': cashback,
          'coupon': coupon,
          'discount': discount,
          'isActive': isActive,
        }),
      );

      if (response.statusCode == 200) {
        return Offers.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update offers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update offers: $e');
    }
  }

  static Future<Offers> addCashback(String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-cashback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return Offers.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to add cashback: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add cashback: $e');
    }
  }

  static Future<Offers> addCoupon(String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-coupon'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return Offers.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to add coupon: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add coupon: $e');
    }
  }

  static Future<Offers> addDiscount(String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-discount'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return Offers.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to add discount: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add discount: $e');
    }
  }

  static Future<Map<String, dynamic>> useCashback(
      String token, double amount) async {
    try {
      print('DEBUG: useCashback called with amount: $amount');
      print('DEBUG: Token: ${token.substring(0, 20)}...');
      
      final requestBody = {'amount': amount};
      print('DEBUG: Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/use-cashback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('DEBUG: Parsed response data: $responseData');
        
        return {
          'offers': Offers.fromJson(responseData['offers']),
          'wallet': responseData['wallet'],
          'message': responseData['message'],
        };
      } else {
        print('DEBUG: Request failed with status: ${response.statusCode}');
        throw Exception('Failed to use cashback: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Error in useCashback: $e');
      throw Exception('Failed to use cashback: $e');
    }
  }

  static Future<Map<String, dynamic>> useCoupon(
      String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/use-coupon'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'offers': Offers.fromJson(responseData['offers']),
          'wallet': responseData['wallet'],
          'message': responseData['message'],
        };
      } else {
        throw Exception('Failed to use coupon: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to use coupon: $e');
    }
  }

  static Future<Map<String, dynamic>> useDiscount(
      String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/use-discount'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'offers': Offers.fromJson(responseData['offers']),
          'wallet': responseData['wallet'],
          'message': responseData['message'],
        };
      } else {
        throw Exception('Failed to use discount: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to use discount: $e');
    }
  }
}
