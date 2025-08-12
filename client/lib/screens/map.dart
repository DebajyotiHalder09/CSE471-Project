import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/bus.dart';
import 'nav.dart';
import 'rideshare.dart';

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

  // Dhaka City boundaries
  static const LatLng dhakaCenter = LatLng(23.8103, 90.4125);
  static const double dhakaMinLat = 23.6;
  static const double dhakaMaxLat = 24.0;
  static const double dhakaMinLng = 90.2;
  static const double dhakaMaxLng = 90.6;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    _mapController = MapController();
    // Wait for the next frame to ensure the map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapController != null) {
        setState(() {
          _mapReady = true;
        });
        _mapController!.move(dhakaCenter, _currentZoom);
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<LatLng?> _getCoordinates(String query) async {
    if (query.trim().isEmpty) return null;

    // Add "Dhaka, Bangladesh" to improve search accuracy
    String searchQuery = query.trim();
    if (!searchQuery.toLowerCase().contains('dhaka')) {
      searchQuery = '$searchQuery, Dhaka, Bangladesh';
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=5&viewbox=$dhakaMinLng,$dhakaMaxLat,$dhakaMaxLng,$dhakaMinLat&bounded=1');

    try {
      final response =
          await http.get(url, headers: {'User-Agent': 'flutter_map_app'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);

          // Check if the result is within Dhaka City boundaries
          if (lat >= dhakaMinLat &&
              lat <= dhakaMaxLat &&
              lon >= dhakaMinLng &&
              lon <= dhakaMaxLng) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }
    return null;
  }

  Future<void> _searchSource() async {
    if (_sourceController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final coordinates = await _getCoordinates(_sourceController.text);

    setState(() {
      _isLoading = false;
      if (coordinates != null) {
        _sourcePoint = coordinates;
        if (_mapController != null && _mapReady) {
          _mapController!.move(coordinates, 15.0);
        }
        _updateRoute();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Could not find source location: ${_sourceController.text}")),
        );
      }
    });
  }

  Future<void> _searchDestination() async {
    if (_destinationController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final coordinates = await _getCoordinates(_destinationController.text);

    setState(() {
      _isLoading = false;
      if (coordinates != null) {
        _destinationPoint = coordinates;
        if (_mapController != null && _mapReady) {
          _mapController!.move(coordinates, 15.0);
        }
        _updateRoute();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Could not find destination location: ${_destinationController.text}")),
        );
      }
    });
  }

  Future<void> _updateRoute() async {
    if (_sourcePoint == null || _destinationPoint == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get route using OSRM (Open Source Routing Machine)
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

            // Fit map to show entire route
            _fitMapToRoute();
          }
        }
      } else {
        // Fallback to straight line if routing fails
        setState(() {
          _routePoints = [_sourcePoint!, _destinationPoint!];
        });
        _fitMapToRoute();
      }
    } catch (e) {
      print('Error getting route: $e');
      // Fallback to straight line
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
      });
      return;
    }

    setState(() {
      _busesLoading = true;
      _busesError = null;
      _availableBuses = [];
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
                          // Use the callback to switch to rideshare tab instead of pushing a new page
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
                                  itemCount: _availableBuses.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final bus = _availableBuses[index];
                                    return ListTile(
                                      leading: const Icon(Icons.directions_bus,
                                          color: Colors.blue),
                                      title: Text(bus.busName),
                                      subtitle:
                                          Text('${bus.stops.length} stops'),
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
              // Base map - Carto Light
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              // Route line
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
              // Markers
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

          // Search fields
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Source field
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
                      onPressed: _searchSource,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _searchSource(),
                ),
                const SizedBox(height: 8),
                // Destination field
                TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: "Enter destination location",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.flag, color: Colors.red),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchDestination,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _searchDestination(),
                ),
              ],
            ),
          ),

          // Clear button
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

          // Loading indicator
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
