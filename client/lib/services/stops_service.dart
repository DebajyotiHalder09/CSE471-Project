import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StopData {
  final String name;
  final double lat;
  final double lng;

  StopData({
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory StopData.fromJson(Map<String, dynamic> json) {
    return StopData(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class StopsService {
  // Cache for recent searches (LRU-like behavior)
  static final Map<String, List<StopData>> _cache = {};
  static const int _maxCacheSize = 50;
  
  // Track active requests to cancel them if needed
  static final Map<String, http.Client> _activeClients = {};

  /// Optimized search stops by query string with caching and request cancellation
  /// Returns a list of StopData objects with name, lat, lng
  static Future<List<StopData>> searchStops(String query, {String? requestId}) async {
    try {
      final trimmedQuery = query.trim();
      
      // Early return for empty query
      if (trimmedQuery.isEmpty) {
        return [];
      }

      // Check cache first (fastest path)
      final cacheKey = trimmedQuery.toLowerCase();
      if (_cache.containsKey(cacheKey)) {
        return List<StopData>.from(_cache[cacheKey]!);
      }

      // Cancel previous request if same requestId
      if (requestId != null && _activeClients.containsKey(requestId)) {
        _activeClients[requestId]?.close();
        _activeClients.remove(requestId);
      }

      final uri = Uri.parse('${AuthService.baseUrl}/api/stops/search').replace(
        queryParameters: {
          'q': trimmedQuery,
        },
      );

      // Create new client for this request
      final client = http.Client();
      if (requestId != null) {
        _activeClients[requestId] = client;
      }

      try {
        final response = await client.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 3), // Reduced timeout for faster failure
          onTimeout: () {
            throw Exception('Request timeout');
          },
        );

        // Clean up client
        if (requestId != null) {
          _activeClients.remove(requestId);
        }
        client.close();

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> stopsList = data['data'] as List<dynamic>;
            final result = stopsList
                .map((stop) => StopData.fromJson(stop as Map<String, dynamic>))
                .toList();
            
            // Cache result (with size limit)
            _updateCache(cacheKey, result);
            
            return result;
          }
        }

        return [];
      } catch (e) {
        // Clean up client on error
        if (requestId != null) {
          _activeClients.remove(requestId);
        }
        client.close();
        rethrow;
      }
    } catch (e) {
      // Don't log timeout errors (expected behavior)
      if (!e.toString().contains('timeout')) {
        print('Error searching stops: $e');
      }
      return [];
    }
  }

  /// Update cache with LRU-like behavior
  static void _updateCache(String key, List<StopData> value) {
    // Remove oldest entries if cache is too large
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = value;
  }

  /// Clear cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Cancel all active requests
  static void cancelAllRequests() {
    for (final client in _activeClients.values) {
      client.close();
    }
    _activeClients.clear();
  }

  /// Get stop coordinates by exact name match
  /// Returns StopData if found, null otherwise
  static Future<StopData?> getStopCoordinates(String name) async {
    try {
      if (name.trim().isEmpty) {
        return null;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/api/stops/coordinates').replace(
        queryParameters: {
          'name': name.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 2), // Fast timeout for coordinate lookup
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['data'] != null) {
          final stopData = data['data'] as Map<String, dynamic>;
          return StopData.fromJson(stopData);
        }
      }

      return null;
    } catch (e) {
      // Don't log timeout errors
      if (!e.toString().contains('timeout')) {
        print('Error getting stop coordinates: $e');
      }
      return null;
    }
  }
}

