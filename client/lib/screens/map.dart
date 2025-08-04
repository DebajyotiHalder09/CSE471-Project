import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(23.8103, 90.4125), // Dhaka coordinates
          zoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                '© CARTO, © OpenStreetMap contributors',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
