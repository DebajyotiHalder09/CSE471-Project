import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/stops_service.dart' show StopsService, StopData;
import '../models/bus.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  Timer? _sourceDebounceTimer;
  Timer? _destinationDebounceTimer;
  
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  
  List<BusStop> _allBusStops = [];
  
  // Store coordinates for selected addresses
  Map<String, double>? _sourceCoordinates;
  Map<String, double>? _destinationCoordinates;
  
  // Request IDs for cancellation
  String? _sourceRequestId;
  String? _destinationRequestId;

  @override
  void initState() {
    super.initState();
    _sourceController.addListener(_onSourceChanged);
    _destinationController.addListener(_onDestinationChanged);
    _loadAllBusStops();
  }

  @override
  void dispose() {
    _sourceDebounceTimer?.cancel();
    _destinationDebounceTimer?.cancel();
    _sourceController.removeListener(_onSourceChanged);
    _destinationController.removeListener(_onDestinationChanged);
    _sourceController.dispose();
    _destinationController.dispose();
    // Cancel any pending requests
    if (_sourceRequestId != null) {
      StopsService.cancelAllRequests();
    }
    if (_destinationRequestId != null) {
      StopsService.cancelAllRequests();
    }
    super.dispose();
  }

  Future<void> _loadAllBusStops() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final uri = Uri.parse('${AuthService.baseUrl}/bus/all');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> buses = data['data'] as List<dynamic>? ?? [];

        final Set<String> uniqueStopNames = <String>{};
        final List<BusStop> allStops = <BusStop>[];

        for (final bus in buses) {
          final List<dynamic> stops = bus['stops'] as List<dynamic>? ?? [];
          for (final stop in stops) {
            if (stop is Map<String, dynamic> && stop['name'] != null) {
              final stopName = stop['name'].toString().toLowerCase().trim();
              if (!uniqueStopNames.contains(stopName)) {
                uniqueStopNames.add(stopName);
                
                if (stop['lat'] != null && stop['lng'] != null) {
                  allStops.add(BusStop(
                    name: stop['name'],
                    latitude: (stop['lat'] ?? 0.0).toDouble(),
                    longitude: (stop['lng'] ?? 0.0).toDouble(),
                  ));
                }
              }
            }
          }
        }

        setState(() {
          _allBusStops = allStops;
        });
      }
    } catch (e) {
      print('Error loading bus stops: $e');
    }
  }

  void _onSourceChanged() {
    _sourceDebounceTimer?.cancel();
    // Optimized debounce: 250ms for faster response
    _sourceDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      final query = _sourceController.text.trim();
      if (query.isNotEmpty) {
        // Generate new request ID for cancellation
        _sourceRequestId = 'source_${DateTime.now().millisecondsSinceEpoch}';
        _getSearchSuggestions(query, 'source', _sourceRequestId);
      } else {
        // Cancel previous request
        if (_sourceRequestId != null) {
          StopsService.cancelAllRequests();
          _sourceRequestId = null;
        }
        setState(() {
          _sourceSuggestions = [];
        });
      }
    });
  }

  void _onDestinationChanged() {
    _destinationDebounceTimer?.cancel();
    // Optimized debounce: 250ms for faster response
    _destinationDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      final query = _destinationController.text.trim();
      if (query.isNotEmpty) {
        // Generate new request ID for cancellation
        _destinationRequestId = 'destination_${DateTime.now().millisecondsSinceEpoch}';
        _getSearchSuggestions(query, 'destination', _destinationRequestId);
      } else {
        // Cancel previous request
        if (_destinationRequestId != null) {
          StopsService.cancelAllRequests();
          _destinationRequestId = null;
        }
        setState(() {
          _destinationSuggestions = [];
        });
      }
    });
  }

  Future<void> _getSearchSuggestions(String query, String field, String? requestId) async {
    if (query.isEmpty) {
      // Use microtask for faster state update
      Future.microtask(() {
        if (mounted) {
          setState(() {
            if (field == 'source') {
              _sourceSuggestions = [];
            } else {
              _destinationSuggestions = [];
            }
          });
        }
      });
      return;
    }

    final List<Map<String, dynamic>> suggestions = [];

    // 1. Fast autocomplete search from MongoDB stops collection (optimized)
    try {
      final stopsData = await StopsService.searchStops(query, requestId: requestId);
      
      // Check if widget is still mounted before processing
      if (!mounted) return;
      
      // Get reference point for distance calculation (use Dhaka center as default)
      // In future, this can be user's current location
      const referenceLat = 23.8103; // Dhaka center
      const referenceLng = 90.4125;
      
      // Create list with distance for sorting
      final stopsWithDistance = stopsData.map((stop) {
        final distance = _fastDistance(
          referenceLat, referenceLng,
          stop.lat, stop.lng,
        );
        return {
          'stop': stop,
          'distance': distance,
        };
      }).toList();
      
      // Sort by distance (closest first)
      stopsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );
      
      // Add stops to suggestions with coordinates from MongoDB
      for (final item in stopsWithDistance) {
        final stop = item['stop'] as StopData;
        
        suggestions.add({
          'name': stop.name,
          'type': 'stop',
          'latitude': stop.lat,
          'longitude': stop.lng,
          'displayName': stop.name,
        });
      }
    } catch (e) {
      // Don't log timeout errors (expected behavior)
      if (e.toString().contains('timeout') == false) {
        print('Error searching stops from MongoDB: $e');
      }
    }

    // 2. Get geocoding suggestions (detailed addresses) if we have less than 10 suggestions
    if (suggestions.length < 10) {
      try {
        final geocodingResults = await _getGeocodingSuggestions(query);
        
        // Deduplicate: check if geocoding result matches any stop
        for (final geoResult in geocodingResults) {
          final geoName = geoResult['displayName'].toString().toLowerCase();
          final geoLat = geoResult['latitude'] as double;
          final geoLng = geoResult['longitude'] as double;
          
          // Check if this geocoding result matches any existing suggestion
          bool isDuplicate = suggestions.any((s) => 
            s['displayName'].toString().toLowerCase() == geoName
          );
          
          // Also check if too close to any bus stop
          if (!isDuplicate) {
            for (final stop in _allBusStops) {
              final distance = _calculateDistance(
                geoLat, geoLng,
                stop.latitude, stop.longitude,
              );
              // If within 100 meters, consider it a duplicate
              if (distance < 0.1) {
                isDuplicate = true;
                break;
              }
            }
          }
          
          if (!isDuplicate && suggestions.length < 10) {
            suggestions.add(geoResult);
          }
        }
      } catch (e) {
        print('Error getting geocoding suggestions: $e');
      }
    }

    // Sort suggestions: stops first, then geocoding
    suggestions.sort((a, b) {
      final aType = a['type'] as String;
      final bType = b['type'] as String;
      
      if (aType == 'stop' && bType != 'stop') return -1;
      if (bType == 'stop' && aType != 'stop') return 1;
      
      // Within same type, sort alphabetically
      final aName = a['displayName'].toString().toLowerCase();
      final bName = b['displayName'].toString().toLowerCase();
      
      return aName.compareTo(bName);
    });

    // Limit total suggestions to 10
    final limitedSuggestions = suggestions.take(10).toList();

    // Use microtask for faster state update (non-blocking)
    Future.microtask(() {
      if (mounted) {
        setState(() {
          if (field == 'source') {
            _sourceSuggestions = limitedSuggestions;
          } else {
            _destinationSuggestions = limitedSuggestions;
          }
        });
      }
    });
  }

  /// Ultra-fast distance calculation using optimized Haversine formula
  /// Returns distance in kilometers
  /// Optimized for speed: pre-calculated constants, minimized function calls
  double _fastDistance(double lat1, double lng1, double lat2, double lng2) {
    // Pre-calculated constants for speed
    const double earthRadiusKm = 6371.0;
    const double piOver180 = 0.017453292519943295; // pi / 180
    
    // Convert to radians (optimized)
    final dLat = (lat2 - lat1) * piOver180;
    final dLng = (lng2 - lng1) * piOver180;
    
    final lat1Rad = lat1 * piOver180;
    final lat2Rad = lat2 * piOver180;
    
    // Haversine formula (optimized)
    final sinDLat = math.sin(dLat * 0.5);
    final sinDLng = math.sin(dLng * 0.5);
    final a = sinDLat * sinDLat + 
        math.cos(lat1Rad) * math.cos(lat2Rad) * sinDLng * sinDLng;
    
    return earthRadiusKm * 2.0 * math.asin(math.sqrt(a));
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return _fastDistance(lat1, lng1, lat2, lng2);
  }

  Future<List<Map<String, dynamic>>> _getGeocodingSuggestions(String query) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': '$query, Dhaka, Bangladesh',
          'format': 'json',
          'limit': '5',
          'addressdetails': '1',
          'countrycodes': 'bd',
        },
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'CSE471-Project/1.0 (search)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body) as List<dynamic>;
        
        return results.map((result) {
          final displayName = result['display_name'] as String? ?? '';
          final lat = double.tryParse(result['lat']?.toString() ?? '0') ?? 0.0;
          final lng = double.tryParse(result['lon']?.toString() ?? '0') ?? 0.0;
          
          return {
            'name': displayName,
            'type': 'geocoding',
            'latitude': lat,
            'longitude': lng,
            'displayName': displayName,
          };
        }).toList();
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    
    return [];
  }

  void _showSuggestionModal(String field) {
    final controller = field == 'source' ? _sourceController : _destinationController;
    final currentText = controller.text.trim();
    
    // If there's text, trigger search immediately
    if (currentText.isNotEmpty) {
      final requestId = '${field}_${DateTime.now().millisecondsSinceEpoch}';
      if (field == 'source') {
        _sourceRequestId = requestId;
      } else {
        _destinationRequestId = requestId;
      }
      _getSearchSuggestions(currentText, field, requestId);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Fixed search bar at top
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: field == 'source' 
                            ? 'Enter source location' 
                            : 'Enter destination location',
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: Icon(
                          field == 'source' ? Icons.location_on : Icons.flag,
                          color: field == 'source' ? Colors.green : Colors.red,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: field == 'source' ? Colors.green : Colors.red,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.trim().isNotEmpty) {
                          final requestId = '${field}_${DateTime.now().millisecondsSinceEpoch}';
                          if (field == 'source') {
                            _sourceRequestId = requestId;
                          } else {
                            _destinationRequestId = requestId;
                          }
                          _getSearchSuggestions(value.trim(), field, requestId);
                          setModalState(() {}); // Trigger rebuild
                        } else {
                          setModalState(() {
                            if (field == 'source') {
                              _sourceSuggestions = [];
                            } else {
                              _destinationSuggestions = [];
                            }
                          });
                        }
                      },
                    ),
                  ),
                  // Scrollable suggestions list
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final suggestions = field == 'source' 
                            ? _sourceSuggestions 
                            : _destinationSuggestions;
                        
                        if (suggestions.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  controller.text.trim().isEmpty
                                      ? 'Start typing to search...'
                                      : 'No suggestions found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            final isStop = suggestion['type'] == 'stop';
                            
                            return ListTile(
                              leading: Icon(
                                isStop ? Icons.directions_bus : Icons.location_on,
                                color: isStop 
                                    ? Colors.blue 
                                    : (field == 'source' ? Colors.green : Colors.red),
                              ),
                              title: Text(
                                suggestion['displayName'] as String,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _selectSuggestion(suggestion, field);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, String field) {
    final selectedText = suggestion['displayName'] as String;
    final lat = suggestion['latitude'] as double?;
    final lng = suggestion['longitude'] as double?;
    
    setState(() {
      if (field == 'source') {
        _sourceController.text = selectedText;
        _sourceSuggestions = [];
        // Store coordinates if available
        if (lat != null && lng != null) {
          _sourceCoordinates = {'lat': lat, 'lon': lng};
        } else {
          _sourceCoordinates = null;
        }
      } else {
        _destinationController.text = selectedText;
        _destinationSuggestions = [];
        // Store coordinates if available
        if (lat != null && lng != null) {
          _destinationCoordinates = {'lat': lat, 'lon': lng};
        } else {
          _destinationCoordinates = null;
        }
      }
    });
  }

  void _navigateToMap() {
    if (_sourceController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both source and destination'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If coordinates are not stored, try to find them from bus stops
    if (_sourceCoordinates == null && _allBusStops.isNotEmpty) {
      try {
        final sourceText = _sourceController.text.trim().toLowerCase();
        final sourceStop = _allBusStops.firstWhere(
          (stop) => stop.name.toLowerCase() == sourceText,
          orElse: () => _allBusStops.firstWhere(
            (stop) => stop.name.toLowerCase().contains(sourceText) ||
                       sourceText.contains(stop.name.toLowerCase()),
            orElse: () => BusStop(name: '', latitude: 0, longitude: 0),
          ),
        );
        if (sourceStop.name.isNotEmpty) {
          _sourceCoordinates = {'lat': sourceStop.latitude, 'lon': sourceStop.longitude};
        }
      } catch (e) {
        // No matching bus stop found, coordinates will be null
      }
    }

    if (_destinationCoordinates == null && _allBusStops.isNotEmpty) {
      try {
        final destText = _destinationController.text.trim().toLowerCase();
        final destStop = _allBusStops.firstWhere(
          (stop) => stop.name.toLowerCase() == destText,
          orElse: () => _allBusStops.firstWhere(
            (stop) => stop.name.toLowerCase().contains(destText) ||
                       destText.contains(stop.name.toLowerCase()),
            orElse: () => BusStop(name: '', latitude: 0, longitude: 0),
          ),
        );
        if (destStop.name.isNotEmpty) {
          _destinationCoordinates = {'lat': destStop.latitude, 'lon': destStop.longitude};
        }
      } catch (e) {
        // No matching bus stop found, coordinates will be null
      }
    }

    Navigator.of(context).pop({
      'source': _sourceController.text.trim(),
      'destination': _destinationController.text.trim(),
      'sourceCoordinates': _sourceCoordinates,
      'destinationCoordinates': _destinationCoordinates,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Search Location',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Source field
                TextField(
                  controller: _sourceController,
                  onTap: () {
                    _showSuggestionModal('source');
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter source location',
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Destination field
                TextField(
                  controller: _destinationController,
                  onTap: () {
                    _showSuggestionModal('destination');
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter destination location',
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.flag, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _navigateToMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
