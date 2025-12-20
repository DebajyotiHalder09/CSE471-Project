import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/stops_service.dart' show StopsService, StopData;
import '../models/bus.dart';
import '../utils/app_theme.dart';
import '../utils/error_widgets.dart';

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
    _sourceDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      final query = _sourceController.text.trim();
      if (query.isNotEmpty) {
        _sourceRequestId = 'source_${DateTime.now().millisecondsSinceEpoch}';
        _getSearchSuggestions(query, 'source', _sourceRequestId);
      } else {
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
    _destinationDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      final query = _destinationController.text.trim();
      if (query.isNotEmpty) {
        _destinationRequestId = 'destination_${DateTime.now().millisecondsSinceEpoch}';
        _getSearchSuggestions(query, 'destination', _destinationRequestId);
      } else {
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

    // 1. Fast autocomplete search from MongoDB stops collection
    try {
      final stopsData = await StopsService.searchStops(query, requestId: requestId);
      
      if (!mounted) return;
      
      const referenceLat = 23.8103; // Dhaka center
      const referenceLng = 90.4125;
      
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
      
      stopsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );
      
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
      if (e.toString().contains('timeout') == false) {
        print('Error searching stops from MongoDB: $e');
      }
    }

    // 2. Get geocoding suggestions if we have less than 10 suggestions
    if (suggestions.length < 10) {
      try {
        final geocodingResults = await _getGeocodingSuggestions(query);
        
        for (final geoResult in geocodingResults) {
          final geoName = geoResult['displayName'].toString().toLowerCase();
          final geoLat = geoResult['latitude'] as double;
          final geoLng = geoResult['longitude'] as double;
          
          bool isDuplicate = suggestions.any((s) => 
            s['displayName'].toString().toLowerCase() == geoName
          );
          
          if (!isDuplicate) {
            for (final stop in _allBusStops) {
              final distance = _calculateDistance(
                geoLat, geoLng,
                stop.latitude, stop.longitude,
              );
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
      
      final aName = a['displayName'].toString().toLowerCase();
      final bName = b['displayName'].toString().toLowerCase();
      
      return aName.compareTo(bName);
    });

    final limitedSuggestions = suggestions.take(10).toList();

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

  double _fastDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371.0;
    const double piOver180 = 0.017453292519943295;
    
    final dLat = (lat2 - lat1) * piOver180;
    final dLng = (lng2 - lng1) * piOver180;
    
    final lat1Rad = lat1 * piOver180;
    final lat2Rad = lat2 * piOver180;
    
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              height: MediaQuery.of(context).size.height * 0.95,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Fixed search bar at top
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: AppTheme.bodyLargeDark(context),
                      decoration: InputDecoration(
                        hintText: field == 'source' 
                            ? 'Enter source location' 
                            : 'Enter destination location',
                        hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: field == 'source'
                                ? LinearGradient(
                                    colors: [
                                      AppTheme.accentGreen,
                                      AppTheme.accentGreen.withOpacity(0.8),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppTheme.accentRed,
                                      AppTheme.accentRed.withOpacity(0.8),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            field == 'source' ? Icons.location_on_rounded : Icons.flag_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: field == 'source' ? AppTheme.accentGreen : AppTheme.accentRed,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
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
                          setModalState(() {});
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
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        
                        if (suggestions.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark 
                                        ? AppTheme.darkSurfaceElevated 
                                        : AppTheme.backgroundLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search_rounded,
                                    size: 48,
                                    color: isDark 
                                        ? AppTheme.darkTextTertiary 
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  controller.text.trim().isEmpty
                                      ? 'Start typing to search...'
                                      : 'No suggestions found',
                                  style: AppTheme.heading4Dark(context).copyWith(
                                    color: isDark 
                                        ? AppTheme.darkTextSecondary 
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try searching for bus stops or locations',
                                  style: AppTheme.bodyMediumDark(context).copyWith(
                                    color: isDark 
                                        ? AppTheme.darkTextTertiary 
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            final isStop = suggestion['type'] == 'stop';
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: AppTheme.modernCardDecorationDark(
                                context,
                                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _selectSuggestion(suggestion, field);
                                    Navigator.of(context).pop();
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: isStop
                                                ? AppTheme.primaryGradient
                                                : (field == 'source'
                                                    ? LinearGradient(
                                                        colors: [
                                                          AppTheme.accentGreen,
                                                          AppTheme.accentGreen.withOpacity(0.8),
                                                        ],
                                                      )
                                                    : LinearGradient(
                                                        colors: [
                                                          AppTheme.accentRed,
                                                          AppTheme.accentRed.withOpacity(0.8),
                                                        ],
                                                      )),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isStop 
                                                ? Icons.directions_bus_filled 
                                                : Icons.location_on_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                suggestion['displayName'] as String,
                                                style: AppTheme.bodyLargeDark(context).copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (isStop) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryBlue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Bus Stop',
                                                    style: AppTheme.labelSmall.copyWith(
                                                      color: AppTheme.primaryBlue,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: isDark 
                                              ? AppTheme.darkTextTertiary 
                                              : AppTheme.textTertiary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
        if (lat != null && lng != null) {
          _sourceCoordinates = {'lat': lat, 'lon': lng};
        } else {
          _sourceCoordinates = null;
        }
      } else {
        _destinationController.text = selectedText;
        _destinationSuggestions = [];
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
      ErrorSnackbar.show(
        context,
        'Please enter both source and destination',
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
        // No matching bus stop found
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
        // No matching bus stop found
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Search Location',
              style: AppTheme.heading3Dark(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Source field
            Container(
              decoration: AppTheme.modernCardDecorationDark(
                context,
                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
              ),
              child: TextField(
                controller: _sourceController,
                style: AppTheme.bodyLargeDark(context),
                onTap: () {
                  _showSuggestionModal('source');
                },
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Enter source location',
                  hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentGreen,
                          AppTheme.accentGreen.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  suffixIcon: _sourceController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _sourceController.clear();
                              _sourceCoordinates = null;
                            });
                          },
                        )
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.accentGreen,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Arrow icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppTheme.darkSurfaceElevated 
                      : AppTheme.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Destination field
            Container(
              decoration: AppTheme.modernCardDecorationDark(
                context,
                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
              ),
              child: TextField(
                controller: _destinationController,
                style: AppTheme.bodyLargeDark(context),
                onTap: () {
                  _showSuggestionModal('destination');
                },
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Enter destination location',
                  hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentRed,
                          AppTheme.accentRed.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  suffixIcon: _destinationController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _destinationController.clear();
                              _destinationCoordinates = null;
                            });
                          },
                        )
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.accentRed,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Search button
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToMap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search Route',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
