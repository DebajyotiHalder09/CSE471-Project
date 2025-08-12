import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/review.dart';

class ReviewService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<Map<String, dynamic>> getReviewsByBusId(String busId) async {
    try {
      print('Fetching reviews for busId: $busId');
      print('URL: $baseUrl/api/reviews/bus/$busId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/reviews/bus/$busId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['reviews'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch reviews: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error fetching reviews: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> createReview({
    required String busId,
    required String userId,
    required String userName,
    required String comment,
  }) async {
    try {
      print('Creating review for busId: $busId');
      print('URL: $baseUrl/api/reviews');
      print(
          'Data: {"busId": "$busId", "userId": "$userId", "userName": "$userName", "comment": "$comment"}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'busId': busId,
          'userId': userId,
          'userName': userName,
          'comment': comment,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['review'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create review: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creating review: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> likeReview({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews/$reviewId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Failed to like review',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> dislikeReview({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews/$reviewId/dislike'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Failed to dislike review',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> addReply({
    required String reviewId,
    required String userId,
    required String userName,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews/$reviewId/reply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userName': userName,
          'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['reply'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to add reply',
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
