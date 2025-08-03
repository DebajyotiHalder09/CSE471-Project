import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  LatLng? _sourceLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  bool _isLoading = false;
  
  // Search suggestions
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _showSourceSuggestions = false;
  bool _showDestinationSuggestions = false;
  Timer? _searchTimer;
  
  // Default center
  LatLng _center = LatLng(40.7128, -74.0060); // NYC

  @override
  void initState() {
    super.initState();
    _addDefaultMarker();
    
    // Add listeners for search suggestions
    _sourceController.addListener(() => _onSearchTextChanged(_sourceController.text, true));
    _destinationController.addListener(() => _onSearchTextChanged(_destinationController.text, false));
  }

  void _addDefaultMarker() {
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Container(
          child: Icon(Icons.location_on, color: Colors.blue[700], size: 40),
        ),
      ),
    );
  }

  void _onSearchTextChanged(String query, bool isSource) {
    _searchTimer?.cancel();
    
    if (query.length < 3) {
      setState(() {
        if (isSource) {
          _sourceSuggestions.clear();
          _showSourceSuggestions = false;
        } else {
          _destinationSuggestions.clear();
          _showDestinationSuggestions = false;
        }
      });
      return;
    }

    _searchTimer = Timer(Duration(milliseconds: 500), () {
      _fetchSuggestions(query, isSource);
    });
  }

  Future<void> _fetchSuggestions(String query, bool isSource) async {
    if (query.length < 3) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1'
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final suggestions = data.map((item) => {
          'display_name': item['display_name'],
          'lat': double.parse(item['lat']),
          'lon': double.parse(item['lon']),
        }).toList();

        setState(() {
          if (isSource) {
            _sourceSuggestions = suggestions;
            _showSourceSuggestions = true;
          } else {
            _destinationSuggestions = suggestions;
            _showDestinationSuggestions = true;
          }
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, bool isSource) {
    final LatLng location = LatLng(suggestion['lat'], suggestion['lon']);
    
    setState(() {
      if (isSource) {
        _sourceLocation = location;
        _sourceController.text = suggestion['display_name'];
        _showSourceSuggestions = false;
        _sourceSuggestions.clear(); // Clear suggestions
      } else {
        _destinationLocation = location;
        _destinationController.text = suggestion['display_name'];
        _showDestinationSuggestions = false;
        _destinationSuggestions.clear(); // Clear suggestions
      }
      // Hide both suggestion overlays to prevent blocking
      _showSourceSuggestions = false;
      _showDestinationSuggestions = false;
      _updateMarkers();
      _mapController.move(location, 15.0);
    });
  }

  Future<void> _searchLocation(String query, bool isSource) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      if (isSource) {
        _showSourceSuggestions = false;
      } else {
        _showDestinationSuggestions = false;
      }
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final location = data[0];
          final lat = double.parse(location['lat']);
          final lon = double.parse(location['lon']);
          final LatLng newLocation = LatLng(lat, lon);

          setState(() {
            if (isSource) {
              _sourceLocation = newLocation;
              _sourceController.text = location['display_name'] ?? query;
            } else {
              _destinationLocation = newLocation;
              _destinationController.text = location['display_name'] ?? query;
            }
            _updateMarkers();
            _mapController.move(newLocation, 15.0);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fitBounds(LatLngBounds bounds) {
    // Calculate center and zoom level to fit bounds
    final center = bounds.center;
    
    // Simple zoom calculation based on bounds size
    final latDiff = bounds.north - bounds.south;
    final lngDiff = bounds.east - bounds.west;
    
    double zoom = 13.0;
    if (latDiff > 0.1 || lngDiff > 0.1) {
      zoom = 10.0;
    } else if (latDiff > 0.01 || lngDiff > 0.01) {
      zoom = 12.0;
    } else {
      zoom = 15.0;
    }
    
    _mapController.move(center, zoom);
  }

  void _updateMarkers() {
    _markers.clear();
    
    if (_sourceLocation != null) {
      _markers.add(
        Marker(
          point: _sourceLocation!,
          width: 100,
          height: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.my_location, color: Colors.white, size: 24),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'FROM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          point: _destinationLocation!,
          width: 100,
          height: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.place, color: Colors.white, size: 24),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _findRoute() async {
    if (_sourceLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please set both source and destination'),
          backgroundColor: Colors.grey[800],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_sourceLocation!.longitude},${_sourceLocation!.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}?overview=full&geometries=geojson'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'];
          
          _routePoints = geometry.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
          
          // Fit bounds to show the entire route
          final bounds = LatLngBounds.fromPoints(_routePoints);
          _fitBounds(bounds);
        }
      } else {
        // Fallback to straight line if routing service fails
        _routePoints = [_sourceLocation!, _destinationLocation!];
        final bounds = LatLngBounds.fromPoints([_sourceLocation!, _destinationLocation!]);
        _fitBounds(bounds);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Routing service unavailable, showing straight line'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }

    } catch (e) {
      // Fallback to straight line on error
      _routePoints = [_sourceLocation!, _destinationLocation!];
      final bounds = LatLngBounds.fromPoints([_sourceLocation!, _destinationLocation!]);
      _fitBounds(bounds);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding route, showing straight line'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Full screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _showSourceSuggestions = false;
                  _showDestinationSuggestions = false;
                });
              },
            ),
            children: [
              // Light minimal map style
              TileLayer(
                urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.app',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _markers),
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: Colors.grey[900]!,
                    ),
                  ],
                ),
            ],
          ),
          // Bottom search UI
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBox(_sourceController, "Where from?", true, Icons.my_location, Colors.green[600]!),
                  SizedBox(height: 16),
                  _buildSearchBox(_destinationController, "Where to?", false, Icons.place, Colors.red[600]!),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _findRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Find Route',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Source suggestions overlay - positioned above bottom sheet
          if (_showSourceSuggestions && _sourceSuggestions.isNotEmpty)
            Positioned(
              bottom: 200 + MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              child: _buildSuggestionsOverlay(_sourceSuggestions, true),
            ),
          // Destination suggestions overlay - positioned above bottom sheet
          if (_showDestinationSuggestions && _destinationSuggestions.isNotEmpty)
            Positioned(
              bottom: 200 + MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              child: _buildSuggestionsOverlay(_destinationSuggestions, false),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsOverlay(List<Map<String, dynamic>> suggestions, bool isSource) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: Colors.grey[700], size: 20),
            ),
            title: Text(
              suggestion['display_name'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              _selectSuggestion(suggestion, isSource);
              // Force hide suggestions immediately
              FocusScope.of(context).unfocus(); // Remove keyboard focus
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBox(TextEditingController controller, String hint, bool isSource, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (value) => _searchLocation(value, isSource),
              onTap: () {
                // Clear opposite suggestions when focusing on a field
                setState(() {
                  if (isSource) {
                    _showDestinationSuggestions = false;
                    _destinationSuggestions.clear();
                  } else {
                    _showSourceSuggestions = false;
                    _sourceSuggestions.clear();
                  }
                });
                
                if (controller.text.length >= 3) {
                  setState(() {
                    if (isSource) {
                      _showSourceSuggestions = true;
                      _showDestinationSuggestions = false;
                    } else {
                      _showDestinationSuggestions = true;
                      _showSourceSuggestions = false;
                    }
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[600]),
            onPressed: () => _searchLocation(controller.text, isSource),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }
}