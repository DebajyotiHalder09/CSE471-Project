import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _sourcePoint;
  LatLng? _destinationPoint;
  double _currentZoom = 13.0;

  Future<LatLng?> _getCoordinates(String query) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    final response = await http.get(url, headers: {
      'User-Agent': 'flutter_map_app'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        return LatLng(
          double.parse(data[0]['lat']),
          double.parse(data[0]['lon']),
        );
      }
    }
    return null;
  }

  Future<void> _updateRoute() async {
    if (_sourceController.text.isEmpty || _destinationController.text.isEmpty) {
      return;
    }

    final src = await _getCoordinates(_sourceController.text);
    final dst = await _getCoordinates(_destinationController.text);

    if (src != null && dst != null) {
      setState(() {
        _sourcePoint = src;
        _destinationPoint = dst;
      });

      final midLat = (src.latitude + dst.latitude) / 2;
      final midLng = (src.longitude + dst.longitude) / 2;
      _mapController.move(LatLng(midLat, midLng), _currentZoom);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not find one or both locations.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(23.8103, 90.4125),
              initialZoom: _currentZoom,
            ),
            children: [
              // Base map
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              // Darker labels
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              // Markers
              MarkerLayer(
                markers: [
                  if (_sourcePoint != null)
                    Marker(
                      point: _sourcePoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          color: Colors.green, size: 35),
                    ),
                  if (_destinationPoint != null)
                    Marker(
                      point: _destinationPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag,
                          color: Colors.red, size: 35),
                    ),
                ],
              ),
              // Route line
              if (_sourcePoint != null && _destinationPoint != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_sourcePoint!, _destinationPoint!],
                      strokeWidth: 4.0,
                      color: Colors.blue,
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
                TextField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    hintText: "Enter source (e.g. Mugda Hospital)",
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _updateRoute,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: "Enter destination (e.g. Dhanmondi 32)",
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _updateRoute,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
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
