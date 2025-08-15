import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/individual_bus.dart';
import 'auth_service.dart';

class IndividualBusService {
  static Future<Map<String, dynamic>> getIndividualBuses(
      String busInfoId) async {
    try {
      print(
          'IndividualBusService: Getting individual buses for busInfoId: $busInfoId');

      final token = await AuthService.getToken();
      if (token == null) {
        print('IndividualBusService: No token found');
        return {
          'success': false,
          'message': 'Authentication token not found',
          'data': [],
        };
      }

      final uri = Uri.parse('${AuthService.baseUrl}/bus/individual/$busInfoId');
      print('IndividualBusService: Making request to: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('IndividualBusService: Response status: ${response.statusCode}');
      print('IndividualBusService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['data'] as List<dynamic>? ?? [];
        final individualBuses = list
            .map((e) => IndividualBus.fromJson(e as Map<String, dynamic>))
            .toList();

        print(
            'IndividualBusService: Successfully parsed ${individualBuses.length} buses');
        return {
          'success': true,
          'data': individualBuses,
          'message': 'Individual buses fetched successfully',
        };
      } else if (response.statusCode == 404) {
        print('IndividualBusService: No individual buses found (404)');
        return {
          'success': false,
          'message': 'No individual buses found',
          'data': [],
        };
      } else {
        print(
            'IndividualBusService: Request failed with status ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch individual buses',
          'data': [],
        };
      }
    } catch (e) {
      print('IndividualBusService: Error occurred: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'data': [],
      };
    }
  }
}
