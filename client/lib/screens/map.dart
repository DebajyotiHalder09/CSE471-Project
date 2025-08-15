import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/fav_bus_service.dart';
import '../services/individual_bus_service.dart';
import '../models/bus.dart';
import '../models/individual_bus.dart';
import '../utils/distance_calculator.dart' as distance_calc;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.onOpenRideshare});

  final Function(String, String)? onOpenRideshare;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  bool _mapReady = false;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _sourcePoint;
  LatLng? _destinationPoint;
  List<LatLng> _routePoints = [];
  final double _currentZoom = 13.0;
  bool _isLoading = false;
  bool _busesLoading = false;
  List<Bus> _availableBuses = [];
  String? _busesError;
  String? _currentUserId;
  final Map<String, bool> _favoriteStatus = {};

  List<BusStop> _allBusStops = [];

  // Search suggestions
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _showSourceSuggestions = false;
  bool _showDestinationSuggestions = false;

  static const LatLng dhakaCenter = LatLng(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _getCurrentUserId();
    _loadAllBusStops();

    _sourceController.addListener(() => _onSourceChanged());
    _destinationController.addListener(() => _onDestinationChanged());
  }

  void _initializeMap() {
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapController != null) {
        setState(() {
          _mapReady = true;
        });
        _mapController!.move(dhakaCenter, _currentZoom);
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }

  Future<void> _loadFavoriteStatuses() async {
    if (_currentUserId == null) return;

    for (final bus in _availableBuses) {
      try {
        final response = await FavBusService.checkIfFavorited(
          userId: _currentUserId!,
          busId: bus.id,
        );
        if (response['success']) {
          setState(() {
            _favoriteStatus[bus.id] = response['isFavorited'];
          });
        }
      } catch (e) {
        setState(() {
          _favoriteStatus[bus.id] = false;
        });
      }
    }
  }

  void _toggleIndividualBuses(String busInfoId) {
    print('Toggling individual buses for: $busInfoId');
    _showIndividualBusesDialog(busInfoId);
  }

  void _showIndividualBusesDialog(String busInfoId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(20),
            child: FutureBuilder<Map<String, dynamic>>(
              future: IndividualBusService.getIndividualBuses(busInfoId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading individual buses: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[600]),
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!['success']) {
                  return Center(
                    child: Text(
                      'No individual buses found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                final List<IndividualBus> buses = snapshot.data!['data'];

                if (buses.isEmpty) {
                  return Center(
                    child: Text(
                      'No individual buses available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                final sortedBuses = List<IndividualBus>.from(buses);
                if (_sourcePoint != null) {
                  sortedBuses.sort((a, b) {
                    final aDistance = _calculateDistanceFromSource(a);
                    final bDistance = _calculateDistanceFromSource(b);
                    return aDistance.compareTo(bDistance);
                  });
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Individual Buses',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Divider(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedBuses.length,
                        itemBuilder: (context, index) {
                          final bus = sortedBuses[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[100]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          bus.busCode,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: Colors.grey[900],
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(bus.status),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            bus.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        // TODO: Implement board functionality
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        minimumSize: Size(0, 0),
                                      ),
                                      child: Text(
                                        'Board',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.people,
                                        color: Colors.blue[600],
                                        size: 16,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '${bus.currentPassengerCount}/${bus.totalPassengerCapacity}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.green[600],
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '${_calculateDistanceFromSource(bus).toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.orange[600],
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              _calculateETA(bus),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orange[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showStopsDialog(Bus bus) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${bus.busName} - Stops',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: bus.stops.length,
                    itemBuilder: (context, index) {
                      final stop = bus.stops[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue,
                              radius: 20,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return Colors.green;
      case 'stopped':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<Bus> _getSortedBuses() {
    final sortedBuses = List<Bus>.from(_availableBuses);
    sortedBuses.sort((a, b) {
      final aFavorited = _favoriteStatus[a.id] ?? false;
      final bFavorited = _favoriteStatus[b.id] ?? false;

      if (aFavorited && !bFavorited) return -1;
      if (!aFavorited && bFavorited) return 1;
      return 0;
    });
    return sortedBuses;
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

        setState(() {
          _allBusStops = allStops;
        });
      }
    } catch (e) {
      print('Error loading bus stops: $e');
    }
  }

  void _onSourceChanged() {
    if (_sourceController.text.isEmpty) {
      setState(() {
        _showSourceSuggestions = false;
      });
      return;
    }
    _getSearchSuggestions(_sourceController.text, true);
  }

  void _onDestinationChanged() {
    if (_destinationController.text.isEmpty) {
      setState(() {
        _showDestinationSuggestions = false;
      });
      return;
    }
    _getSearchSuggestions(_destinationController.text, false);
  }

  Future<void> _getSearchSuggestions(String query, bool isSource) async {
    if (query.trim().isEmpty) return;

    final suggestions = <Map<String, dynamic>>{};

    for (final stop in _allBusStops) {
      if (stop.name.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add({
          'name': stop.name,
          'type': 'bus_stop',
          'latitude': stop.latitude,
          'longitude': stop.longitude,
          'isExactMatch': stop.name.toLowerCase() == query.toLowerCase(),
        });
      }
    }

    final sortedSuggestions = suggestions.toList();
    sortedSuggestions.sort((a, b) {
      if (a['isExactMatch'] == true && b['isExactMatch'] != true) return -1;
      if (a['isExactMatch'] != true && b['isExactMatch'] == true) return 1;
      return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
    });

    setState(() {
      if (isSource) {
        _sourceSuggestions = sortedSuggestions.take(8).toList();
        _showSourceSuggestions = _sourceSuggestions.isNotEmpty;
      } else {
        _destinationSuggestions = sortedSuggestions.take(8).toList();
        _showDestinationSuggestions = _destinationSuggestions.isNotEmpty;
      }
    });
  }

  void _selectSourceSuggestion(Map<String, dynamic> suggestion) {
    _sourceController.text = suggestion['name'];
    _sourcePoint = LatLng(suggestion['latitude'], suggestion['longitude']);
    if (_mapController != null && _mapReady) {
      _mapController!.move(_sourcePoint!, 15.0);
    }
    _updateRoute();

    setState(() {
      _showSourceSuggestions = false;
      _sourceSuggestions = [];
    });
  }

  void _selectDestinationSuggestion(Map<String, dynamic> suggestion) {
    _destinationController.text = suggestion['name'];
    _destinationPoint = LatLng(suggestion['latitude'], suggestion['longitude']);
    if (_mapController != null && _mapReady) {
      _mapController!.move(_destinationPoint!, 15.0);
    }
    _updateRoute();

    setState(() {
      _showDestinationSuggestions = false;
      _destinationSuggestions = [];
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _hideAllSuggestions() {
    setState(() {
      _showSourceSuggestions = false;
      _showDestinationSuggestions = false;
      _sourceSuggestions = [];
      _destinationSuggestions = [];
    });
  }

  Future<void> _updateRoute() async {
    if (_sourcePoint == null || _destinationPoint == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final routeUrl = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_sourcePoint!.longitude},${_sourcePoint!.latitude};${_destinationPoint!.longitude},${_destinationPoint!.latitude}?overview=full&geometries=geojson');

      final response = await http.get(routeUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];

          if (geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            final routePoints = coordinates.map((coord) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble());
            }).toList();

            setState(() {
              _routePoints = routePoints;
            });

            _fitMapToRoute();
          }
        }
      } else {
        setState(() {
          _routePoints = [_sourcePoint!, _destinationPoint!];
        });
        _fitMapToRoute();
      }
    } catch (e) {
      print('Error getting route: $e');
      setState(() {
        _routePoints = [_sourcePoint!, _destinationPoint!];
      });
      _fitMapToRoute();
    }

    setState(() {
      _isLoading = false;
    });

    await _fetchAvailableBuses();
    if (mounted) {
      _showResultsSheet();
    }
  }

  Future<void> _fetchAvailableBuses() async {
    final startLocation = _sourceController.text.trim();
    final endLocation = _destinationController.text.trim();
    if (startLocation.isEmpty || endLocation.isEmpty) {
      setState(() {
        _availableBuses = [];
        _busesError = null;
        _favoriteStatus.clear();
      });
      return;
    }

    setState(() {
      _busesLoading = true;
      _busesError = null;
      _availableBuses = [];
      _favoriteStatus.clear();
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          _availableBuses = [];
          _busesLoading = false;
          _busesError = 'Authentication required';
        });
        return;
      }

      final uri = Uri.parse(
          '${AuthService.baseUrl}/bus/search-by-route?startLocation=${Uri.encodeComponent(startLocation)}&endLocation=${Uri.encodeComponent(endLocation)}');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['data'] as List<dynamic>? ?? [];
        final buses =
            list.map((e) => Bus.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _availableBuses = buses;
          _busesLoading = false;
          _busesError = null;
        });
        await _loadFavoriteStatuses();
      } else if (response.statusCode == 404) {
        setState(() {
          _availableBuses = [];
          _busesLoading = false;
          _busesError = null;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _availableBuses = [];
          _busesLoading = false;
          _busesError = 'Authentication required';
        });
      } else {
        setState(() {
          _availableBuses = [];
          _busesLoading = false;
          _busesError = 'Failed to load buses';
        });
      }
    } catch (_) {
      setState(() {
        _availableBuses = [];
        _busesLoading = false;
        _busesError = 'Failed to load buses';
      });
    }
  }

  double _calculateRouteDistance(Bus bus) {
    if (_sourcePoint == null || _destinationPoint == null) return 0.0;

    final sourceStop = bus.stops.firstWhere(
      (stop) =>
          stop.name.toLowerCase() ==
          _sourceController.text.trim().toLowerCase(),
      orElse: () => bus.stops.first,
    );

    final destStop = bus.stops.firstWhere(
      (stop) =>
          stop.name.toLowerCase() ==
          _destinationController.text.trim().toLowerCase(),
      orElse: () => bus.stops.last,
    );

    return distance_calc.DistanceCalculator.calculateDistance(
      sourceStop.latitude,
      sourceStop.longitude,
      destStop.latitude,
      destStop.longitude,
    );
  }

  String _calculateETA(IndividualBus bus) {
    if (_sourcePoint == null) return 'N/A';

    final distance = distance_calc.DistanceCalculator.calculateDistance(
      _sourcePoint!.latitude,
      _sourcePoint!.longitude,
      bus.latitude,
      bus.longitude,
    );

    if (bus.averageSpeedKmh <= 0) return 'N/A';

    final timeInHours = distance / bus.averageSpeedKmh;
    final timeInMinutes = (timeInHours * 60).round();

    if (timeInMinutes < 1) {
      return 'Less than 1 min';
    } else if (timeInMinutes < 60) {
      return '${timeInMinutes} min';
    } else {
      final hours = (timeInMinutes / 60).floor();
      final minutes = timeInMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    }
  }

  double _calculateDistanceFromSource(IndividualBus bus) {
    if (_sourcePoint == null) return 0.0;

    return distance_calc.DistanceCalculator.calculateDistance(
      _sourcePoint!.latitude,
      _sourcePoint!.longitude,
      bus.latitude,
      bus.longitude,
    );
  }

  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Bus',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          if (widget.onOpenRideshare != null) {
                            widget.onOpenRideshare!(
                              _sourceController.text.trim(),
                              _destinationController.text.trim(),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car, size: 18),
                            SizedBox(width: 8),
                            Text('RideShare',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _busesLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _busesError != null
                          ? Center(child: Text(_busesError!))
                          : _availableBuses.isEmpty
                              ? const Center(child: Text('No bus available'))
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: _getSortedBuses().length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final bus = _getSortedBuses()[index];
                                    final isFavorited =
                                        _favoriteStatus[bus.id] ?? false;
                                    final distance =
                                        _calculateRouteDistance(bus);
                                    final totalFare =
                                        bus.calculateFare(distance);

                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.grey[100]!),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              bus.busName,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.blue[200]!),
                                            ),
                                            child: Text(
                                              '${distance.toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: Colors.green[200]!),
                                            ),
                                            child: Text(
                                              '৳${totalFare.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.info_outline,
                                                    color: Colors.blue[600],
                                                    size: 16,
                                                  ),
                                                  onPressed: () {
                                                    _toggleIndividualBuses(
                                                        bus.id);
                                                  },
                                                  tooltip:
                                                      'Show individual buses',
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.route,
                                                    color: Colors.green[600],
                                                    size: 16,
                                                  ),
                                                  onPressed: () {
                                                    _showStopsDialog(bus);
                                                  },
                                                  tooltip: 'Show stops',
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty || _mapController == null || !_mapReady) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
      if (point.latitude < minLat) {
        minLat = point.latitude;
      }
      if (point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (point.longitude < minLng) {
        minLng = point.longitude;
      }
      if (point.longitude > maxLng) {
        maxLng = point.longitude;
      }
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 13.0;
    if (maxDiff > 0.1) {
      zoom = 10.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    } else if (maxDiff > 0.01) {
      zoom = 14.0;
    } else {
      zoom = 16.0;
    }

    _mapController!.move(LatLng(centerLat, centerLng), zoom);
  }

  void _clearRoute() {
    setState(() {
      _sourcePoint = null;
      _destinationPoint = null;
      _routePoints = [];
      _sourceController.clear();
      _destinationController.clear();
      _showSourceSuggestions = false;
      _showDestinationSuggestions = false;
      _sourceSuggestions = [];
      _destinationSuggestions = [];
    });
    if (_mapController != null && _mapReady) {
      _mapController!.move(dhakaCenter, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mapController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController!,
            options: MapOptions(
              initialCenter: dhakaCenter,
              initialZoom: _currentZoom,
              minZoom: 10.0,
              maxZoom: 18.0,
              onMapReady: () {
                setState(() {
                  _mapReady = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6.0,
                      color: Colors.blue.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_sourcePoint != null)
                    Marker(
                      point: _sourcePoint!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  if (_destinationPoint != null)
                    Marker(
                      point: _destinationPoint!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.flag,
                            color: Colors.white, size: 30),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _hideAllSuggestions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      hintText: "Enter source location",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon:
                          const Icon(Icons.location_on, color: Colors.green),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          final stop = _allBusStops.firstWhere(
                            (s) =>
                                s.name.toLowerCase() ==
                                _sourceController.text.trim().toLowerCase(),
                            orElse: () => BusStop(
                                name: '', latitude: 0.0, longitude: 0.0),
                          );
                          if (stop.name.isNotEmpty) {
                            _sourcePoint =
                                LatLng(stop.latitude, stop.longitude);
                            if (_mapController != null && _mapReady) {
                              _mapController!.move(_sourcePoint!, 15.0);
                            }
                            _updateRoute();
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) {
                      final stop = _allBusStops.firstWhere(
                        (s) =>
                            s.name.toLowerCase() ==
                            _sourceController.text.trim().toLowerCase(),
                        orElse: () =>
                            BusStop(name: '', latitude: 0.0, longitude: 0.0),
                      );
                      if (stop.name.isNotEmpty) {
                        _sourcePoint = LatLng(stop.latitude, stop.longitude);
                        if (_mapController != null && _mapReady) {
                          _mapController!.move(_sourcePoint!, 15.0);
                        }
                        _updateRoute();
                      }
                    },
                  ),
                  if (_showSourceSuggestions && _sourceSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _sourceSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _sourceSuggestions[index];
                          return GestureDetector(
                            onTap: () => _selectSourceSuggestion(suggestion),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.directions_bus,
                                color: Colors.blue,
                                size: 20,
                              ),
                              title: Text(
                                suggestion['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: suggestion['isExactMatch'] == true
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: "Enter destination location",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.flag, color: Colors.red),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          final stop = _allBusStops.firstWhere(
                            (s) =>
                                s.name.toLowerCase() ==
                                _destinationController.text
                                    .trim()
                                    .toLowerCase(),
                            orElse: () => BusStop(
                                name: '', latitude: 0.0, longitude: 0.0),
                          );
                          if (stop.name.isNotEmpty) {
                            _destinationPoint =
                                LatLng(stop.latitude, stop.longitude);
                            if (_mapController != null && _mapReady) {
                              _mapController!.move(_destinationPoint!, 15.0);
                            }
                            _updateRoute();
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) {
                      final stop = _allBusStops.firstWhere(
                        (s) =>
                            s.name.toLowerCase() ==
                            _destinationController.text.trim().toLowerCase(),
                        orElse: () =>
                            BusStop(name: '', latitude: 0.0, longitude: 0.0),
                      );
                      if (stop.name.isNotEmpty) {
                        _destinationPoint =
                            LatLng(stop.latitude, stop.longitude);
                        if (_mapController != null && _mapReady) {
                          _mapController!.move(_destinationPoint!, 15.0);
                        }
                        _updateRoute();
                      }
                    },
                  ),
                  if (_showDestinationSuggestions &&
                      _destinationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _destinationSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _destinationSuggestions[index];
                          return GestureDetector(
                            onTap: () =>
                                _selectDestinationSuggestion(suggestion),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.directions_bus,
                                color: Colors.blue,
                                size: 20,
                              ),
                              title: Text(
                                suggestion['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: suggestion['isExactMatch'] == true
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_sourcePoint != null || _destinationPoint != null)
            Positioned(
              top: 140,
              right: 16,
              child: FloatingActionButton(
                onPressed: _clearRoute,
                backgroundColor: Colors.red,
                child: const Icon(Icons.clear, color: Colors.white),
              ),
            ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
