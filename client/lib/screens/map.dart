import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/fav_bus_service.dart';
import '../models/bus.dart';
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
  Map<String, bool> _favoriteStatus = {};

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
      final uri = Uri.parse('${AuthService.baseUrl}/bus/all');
      final response = await http.get(uri);
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
      final uri = Uri.parse(
          '${AuthService.baseUrl}/bus/search-by-route?startLocation=${Uri.encodeComponent(startLocation)}&endLocation=${Uri.encodeComponent(endLocation)}');
      final response = await http.get(uri);
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

                                    return ListTile(
                                      leading: Icon(
                                        Icons.directions_bus,
                                        color: Colors.blue,
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(child: Text(bus.busName)),
                                          if (isFavorited)
                                            Icon(
                                              Icons.favorite,
                                              color: Colors.red,
                                              size: 16,
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${bus.stopNames.length} stops'),
                                          Text(
                                            'Distance: ${distance.toStringAsFixed(1)} km',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '৳${totalFare.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                          ),
                                        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _sourceController,
                        decoration: InputDecoration(
                          hintText: "Enter source location",
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.location_on,
                              color: Colors.green),
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
                      if (_showSourceSuggestions &&
                          _sourceSuggestions.isNotEmpty)
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
                              return ListTile(
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
                                    fontWeight:
                                        suggestion['isExactMatch'] == true
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () =>
                                    _selectSourceSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  _mapController!
                                      .move(_destinationPoint!, 15.0);
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
                              return ListTile(
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
                                    fontWeight:
                                        suggestion['isExactMatch'] == true
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () =>
                                    _selectDestinationSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                    ],
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
