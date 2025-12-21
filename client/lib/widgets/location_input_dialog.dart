import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class LocationInputDialog extends StatefulWidget {
  const LocationInputDialog({super.key});

  @override
  State<LocationInputDialog> createState() => _LocationInputDialogState();
}

class _LocationInputDialogState extends State<LocationInputDialog> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.location_on, color: AppTheme.accentRed, size: 24),
          const SizedBox(width: 12),
          const Text('Enter Your Location'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location/Address',
                hintText: 'e.g., Gulshan, Dhaka',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Coordinates (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      hintText: '23.8103',
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      hintText: '90.4125',
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final source = _locationController.text.trim();
            if (source.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a location')),
              );
              return;
            }

            double? lat;
            double? lon;

            if (_latController.text.isNotEmpty && _lonController.text.isNotEmpty) {
              lat = double.tryParse(_latController.text);
              lon = double.tryParse(_lonController.text);
            }

            Navigator.pop(context, {
              'source': source,
              'latitude': lat,
              'longitude': lon,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentRed,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

