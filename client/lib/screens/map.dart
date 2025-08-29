import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/fav_bus_service.dart';
import '../services/individual_bus_service.dart';
import '../services/trip_history_service.dart';
import '../models/bus.dart';
import '../models/individual_bus.dart';
import '../utils/distance_calculator.dart' as distance_calc;
import 'pay.dart';

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
  String? _currentUserGender;
  final Map<String, bool> _favoriteStatus = {};
  final Map<String, bool> _boardedBuses = {};

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
        _currentUserGender = user.gender;
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

  Bus? _getBusInfoById(String busInfoId) {
    try {
      return _availableBuses.firstWhere((bus) => bus.id == busInfoId);
    } catch (e) {
      return null;
    }
  }

  Future<IndividualBus?> _getIndividualBusById(String busId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/$busId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return IndividualBus.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
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

                List<IndividualBus> filteredBuses =
                    List<IndividualBus>.from(buses);
                if (_currentUserGender?.toLowerCase() == 'male') {
                  filteredBuses =
                      buses.where((bus) => bus.busType != 'women').toList();
                }

                if (filteredBuses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          _currentUserGender?.toLowerCase() == 'male'
                              ? 'No available buses for male passengers'
                              : 'No individual buses available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final sortedBuses = List<IndividualBus>.from(filteredBuses);
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Individual Buses',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (_boardedBuses.values.any((boarded) => boarded))
                              Container(
                                margin: EdgeInsets.only(top: 4),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_bus,
                                      size: 14,
                                      color: Colors.orange[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Currently on a bus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Future.delayed(Duration(milliseconds: 100), () {
                                  if (mounted) {
                                    _showIndividualBusesDialog(busInfoId);
                                  }
                                });
                              },
                              icon:
                                  Icon(Icons.refresh, color: Colors.blue[600]),
                              tooltip: 'Refresh',
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(height: 16),
                    // Show women-only bus suggestion for female users when regular buses are crowded
                    if (_currentUserGender?.toLowerCase() == 'female' &&
                        buses.any((bus) => bus.busType == 'women') &&
                        sortedBuses.any((bus) =>
                            bus.currentPassengerCount >=
                            (bus.totalPassengerCapacity * 0.7)))
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.pink[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.pink[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.woman,
                              color: Colors.pink[600],
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Regular buses are getting crowded',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.pink[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Consider women-only buses for a more comfortable ride',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.pink[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final womenOnlyBuses = buses
                                    .where((bus) => bus.busType == 'women')
                                    .toList();
                                Navigator.of(context).pop();
                                _showWomenOnlyBusesDialog(womenOnlyBuses,
                                    busInfoId: busInfoId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                    Row(
                                      children: [
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
                                        if (bus.busType == 'women') ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.pink[400],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'WOMEN',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: bus.currentPassengerCount >=
                                                    bus.totalPassengerCapacity
                                                ? Colors.red[50]
                                                : bus.currentPassengerCount >=
                                                        (bus.totalPassengerCapacity *
                                                            0.8)
                                                    ? Colors.orange[50]
                                                    : Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.people,
                                            color: bus.currentPassengerCount >=
                                                    bus.totalPassengerCapacity
                                                ? Colors.red[600]
                                                : bus.currentPassengerCount >=
                                                        (bus.totalPassengerCapacity *
                                                            0.8)
                                                    ? Colors.orange[600]
                                                    : Colors.blue[600],
                                            size: 16,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          '${bus.currentPassengerCount}/${bus.totalPassengerCapacity}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: bus.currentPassengerCount >=
                                                    bus.totalPassengerCapacity
                                                ? Colors.red[700]
                                                : bus.currentPassengerCount >=
                                                        (bus.totalPassengerCapacity *
                                                            0.8)
                                                    ? Colors.orange[700]
                                                    : Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      child: !(_boardedBuses[bus.id] ?? false)
                                          ? Tooltip(
                                              message: bus.currentPassengerCount >=
                                                      bus.totalPassengerCapacity
                                                  ? 'Bus is at full capacity'
                                                  : bus.currentPassengerCount >=
                                                          (bus.totalPassengerCapacity *
                                                              0.8)
                                                      ? 'Bus is nearly full'
                                                      : 'Board this bus',
                                              child: ElevatedButton(
                                                key:
                                                    ValueKey('board_${bus.id}'),
                                                onPressed:
                                                    bus.currentPassengerCount >=
                                                            bus.totalPassengerCapacity
                                                        ? null
                                                        : () async {
                                                            if (_currentUserGender
                                                                        ?.toLowerCase() ==
                                                                    'male' &&
                                                                bus.busType ==
                                                                    'women') {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                              _showWomenBusPopup();
                                                              return;
                                                            }

                                                            final source =
                                                                _sourceController
                                                                    .text
                                                                    .trim();
                                                            final destination =
                                                                _destinationController
                                                                    .text
                                                                    .trim();

                                                            if (source
                                                                    .isEmpty ||
                                                                destination
                                                                    .isEmpty) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Please set source and destination first'),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .orange,
                                                                ),
                                                              );
                                                              return;
                                                            }

                                                            await _boardBus(
                                                                bus.id,
                                                                busInfoId);
                                                          },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _boardedBuses
                                                          .values
                                                          .any((boarded) =>
                                                              boarded)
                                                      ? Colors.grey[400]
                                                      : bus.currentPassengerCount >=
                                                              bus
                                                                  .totalPassengerCapacity
                                                          ? Colors.red[400]
                                                          : bus.currentPassengerCount >=
                                                                  (bus.totalPassengerCapacity *
                                                                      0.8)
                                                              ? Colors
                                                                  .orange[600]
                                                              : Colors
                                                                  .blue[600],
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  minimumSize: Size(0, 0),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.directions_bus,
                                                        size: 14),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      bus.currentPassengerCount >=
                                                              bus
                                                                  .totalPassengerCapacity
                                                          ? 'Full'
                                                          : bus.currentPassengerCount >=
                                                                  (bus.totalPassengerCapacity *
                                                                      0.8)
                                                              ? 'Nearly Full'
                                                              : 'Board',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : ElevatedButton(
                                              key: ValueKey('end_${bus.id}'),
                                              onPressed: () async {
                                                if (_currentUserGender
                                                            ?.toLowerCase() ==
                                                        'male' &&
                                                    bus.busType == 'women') {
                                                  Navigator.of(context).pop();
                                                  _showWomenBusPopup();
                                                  return;
                                                }

                                                final source = _sourceController
                                                    .text
                                                    .trim();
                                                final destination =
                                                    _destinationController.text
                                                        .trim();

                                                if (source.isEmpty ||
                                                    destination.isEmpty) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Please set source and destination first'),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                  return;
                                                }

                                                await _endTrip(
                                                    bus.id,
                                                    busInfoId,
                                                    source,
                                                    destination);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red[600],
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                minimumSize: Size(0, 0),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.stop, size: 14),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'End Trip',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
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

  Future<void> _boardBus(String busId, String busInfoId) async {
    try {
      // Check if user is already on another bus
      if (_boardedBuses.values.any((boarded) => boarded)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'You are already on a bus. Please end your current trip first.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final busInfo = _getBusInfoById(busInfoId);
      if (busInfo == null) return;

      final source = _sourceController.text.trim();
      final destination = _destinationController.text.trim();

      if (source.isEmpty || destination.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please set source and destination first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final distance = _calculateRouteDistance(busInfo);
      final fare = busInfo.calculateFare(distance);

      final individualBus = await _getIndividualBusById(busId);
      if (individualBus == null) return;

      // Check if bus is at full capacity
      if (individualBus.currentPassengerCount >=
          individualBus.totalPassengerCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This bus is at full capacity. Cannot board.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.of(context).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PayScreen(
            bus: individualBus,
            busInfo: busInfo,
            source: source,
            destination: destination,
            distance: distance,
            fare: fare,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing boarding'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _endTrip(
      String busId, String busInfoId, String source, String destination) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/end-trip');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': busId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _boardedBuses.clear();
        });

        final busInfo = _getBusInfoById(busInfoId);
        if (busInfo != null) {
          final distance = _calculateRouteDistance(busInfo);
          final fare = busInfo.calculateFare(distance);

          final result = await TripHistoryService.addTrip(
            busId: busInfoId,
            busName: busInfo.busName,
            distance: distance,
            fare: fare,
            source: source,
            destination: destination,
          );

          if (result['success']) {
            Navigator.of(context).pop();
            _showTripEndedPopup();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Trip ended successfully!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );

            Future.delayed(Duration(milliseconds: 2000), () {
              if (mounted) {
                _showIndividualBusesDialog(busInfoId);
              }
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to record trip'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end trip'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ending trip'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showBoardingPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green[600],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Thanks for boarding!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Your trip has been recorded',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showWomenBusPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.woman,
                    size: 48,
                    color: Colors.pink[600],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Women Only Bus',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'This bus is exclusively for female passengers. Male passengers are not allowed to board.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTripEndedPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Trip Ended!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Your trip has been recorded',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
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

  Timer? _sourceDebounceTimer;
  Timer? _destinationDebounceTimer;

  void _onSourceChanged() {
    _sourceDebounceTimer?.cancel();
    _sourceDebounceTimer = Timer(Duration(milliseconds: 300), () {
      if (_sourceController.text.isEmpty) {
        setState(() {
          _showSourceSuggestions = false;
          _sourceSuggestions = [];
        });
        return;
      }
      _getSearchSuggestions(_sourceController.text, true);
    });
  }

  void _onDestinationChanged() {
    _destinationDebounceTimer?.cancel();
    _destinationDebounceTimer = Timer(Duration(milliseconds: 300), () {
      if (_destinationController.text.isEmpty) {
        setState(() {
          _showDestinationSuggestions = false;
          _destinationSuggestions = [];
        });
        return;
      }
      _getSearchSuggestions(_destinationController.text, false);
    });
  }

  Future<void> _getSearchSuggestions(String query, bool isSource) async {
    if (query.trim().isEmpty) {
      setState(() {
        if (isSource) {
          _showSourceSuggestions = false;
          _sourceSuggestions = [];
        } else {
          _showDestinationSuggestions = false;
          _destinationSuggestions = [];
        }
      });
      return;
    }

    print('Getting search suggestions for: "$query" (${isSource ? 'source' : 'destination'})');

    final List<Map<String, dynamic>> suggestions = [];

    // First, add bus stop suggestions
    for (final stop in _allBusStops) {
      if (stop.name.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add({
          'name': stop.name,
          'type': 'bus_stop',
          'latitude': stop.latitude,
          'longitude': stop.longitude,
          'isExactMatch': stop.name.toLowerCase() == query.toLowerCase(),
          'fullAddress': stop.name,
        });
      }
    }

    print('Found ${suggestions.length} bus stop suggestions');

    // Then, add geocoding suggestions
    try {
      final geocodingSuggestions = await _getGeocodingSuggestions(query);
      print('Found ${geocodingSuggestions.length} geocoding suggestions');
      suggestions.addAll(geocodingSuggestions);
    } catch (e) {
      print('Error getting geocoding suggestions: $e');
    }

    // Remove duplicates based on coordinates
    final uniqueSuggestions = <String, Map<String, dynamic>>{};
    for (final suggestion in suggestions) {
      final key = '${suggestion['latitude']}_${suggestion['longitude']}';
      if (!uniqueSuggestions.containsKey(key)) {
        uniqueSuggestions[key] = suggestion;
      }
    }

    final sortedSuggestions = uniqueSuggestions.values.toList();
    sortedSuggestions.sort((a, b) {
      // Exact matches first
      if (a['isExactMatch'] == true && b['isExactMatch'] != true) return -1;
      if (a['isExactMatch'] != true && b['isExactMatch'] == true) return 1;
      
      // Bus stops first
      if (a['type'] == 'bus_stop' && b['type'] != 'bus_stop') return -1;
      if (a['type'] != 'bus_stop' && b['type'] == 'bus_stop') return 1;
      
      // Then by relevance score for locations
      if (a['type'] == 'location' && b['type'] == 'location') {
        final aScore = a['relevanceScore'] ?? 0.0;
        final bScore = b['relevanceScore'] ?? 0.0;
        if (aScore != bScore) return bScore.compareTo(aScore);
      }
      
      // Finally by name
      return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
    });

    print('Final suggestions: ${sortedSuggestions.length}');

    setState(() {
      if (isSource) {
        _sourceSuggestions = sortedSuggestions.take(8).toList();
        _showSourceSuggestions = _sourceSuggestions.isNotEmpty;
        print('Source suggestions: ${_sourceSuggestions.length}, show: $_showSourceSuggestions');
      } else {
        _destinationSuggestions = sortedSuggestions.take(8).toList();
        _showDestinationSuggestions = _destinationSuggestions.isNotEmpty;
        print('Destination suggestions: ${_destinationSuggestions.length}, show: $_showDestinationSuggestions');
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getGeocodingSuggestions(
      String query) async {
    if (query.trim().isEmpty) return [];

    print('Starting geocoding for: "$query"');

    try {
      List<Map<String, dynamic>> suggestions = [];
      
      // Strategy 1: Try with Dhaka context and Bangladesh country code
      print('Strategy 1: With Dhaka context and BD country code');
      suggestions = await _tryGeocodingStrategy(query, 'bd', '$query, Dhaka, Bangladesh');
      if (suggestions.isNotEmpty) {
        print('Strategy 1 successful: ${suggestions.length} results');
        return suggestions;
      }
      
      // Strategy 2: Try with just Dhaka context
      print('Strategy 2: With Dhaka context only');
      suggestions = await _tryGeocodingStrategy(query, null, '$query, Dhaka');
      if (suggestions.isNotEmpty) {
        print('Strategy 2 successful: ${suggestions.length} results');
        return suggestions;
      }
      
      // Strategy 3: Try without any context
      print('Strategy 3: Raw query');
      suggestions = await _tryGeocodingStrategy(query, null, query);
      if (suggestions.isNotEmpty) {
        print('Strategy 3 successful: ${suggestions.length} results');
        return suggestions;
      }
      
      // Strategy 4: Try with just the main part of the query
      final mainPart = _extractMainAddressPart(query);
      if (mainPart != query) {
        print('Strategy 4: Main part "$mainPart" with Dhaka context');
        suggestions = await _tryGeocodingStrategy(mainPart, null, '$mainPart, Dhaka');
        if (suggestions.isNotEmpty) {
          print('Strategy 4 successful: ${suggestions.length} results');
          return suggestions;
        }
      }
      
      // Strategy 5: Try with simplified query
      final simplifiedQuery = _simplifyAddress(query);
      if (simplifiedQuery != query) {
        print('Strategy 5: Simplified "$simplifiedQuery" with Dhaka context');
        suggestions = await _tryGeocodingStrategy(simplifiedQuery, null, '$simplifiedQuery, Dhaka');
        if (suggestions.isNotEmpty) {
          print('Strategy 5 successful: ${suggestions.length} results');
          return suggestions;
        }
      }
      
      print('All geocoding strategies failed for: "$query"');
      return [];
    } catch (e) {
      print('Geocoding error for "$query": $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _tryGeocodingStrategy(
      String query, String? countryCode, String searchQuery) async {
    try {
      final Map<String, String> params = {
        'q': searchQuery,
        'format': 'json',
        'limit': '10',
        'addressdetails': '1',
        'viewbox': '90.2,23.9,90.6,23.6', // Dhaka area bounding box
        'bounded': '1',
      };
      
      if (countryCode != null) {
        params['countrycodes'] = countryCode;
      }
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final url = 'https://nominatim.openstreetmap.org/search?$queryString';
      
      print('Trying geocoding strategy: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'CSE471-Project/1.0 (map)',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Geocoding response: ${data.length} results');
        
        final List<Map<String, dynamic>> suggestions = [];

        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final lat = item['lat']?.toString();
            final lon = item['lon']?.toString();
            final displayName = item['display_name']?.toString() ?? '';
            final importance = item['importance']?.toDouble() ?? 0.0;
            final type = item['type']?.toString() ?? '';

            if (lat != null && lon != null && displayName.isNotEmpty) {
              // Filter out very low importance results
              if (importance < 0.1) continue;
              
              // Create a more meaningful name
              final name = _createDisplayName(displayName);
              
              // Calculate relevance score
              final relevanceScore = _calculateRelevanceScore(query, displayName, importance);

              suggestions.add({
                'name': name,
                'type': 'location',
                'latitude': double.tryParse(lat) ?? 0.0,
                'longitude': double.tryParse(lon) ?? 0.0,
                'isExactMatch': query.toLowerCase() == name.toLowerCase(),
                'fullAddress': displayName,
                'relevanceScore': relevanceScore,
                'importance': importance,
                'placeType': type,
              });
            }
          }
        }

        print('Processed ${suggestions.length} valid suggestions');

        // Sort by relevance and importance
        suggestions.sort((a, b) {
          final aScore = a['relevanceScore'] ?? 0.0;
          final bScore = b['relevanceScore'] ?? 0.0;
          if (aScore != bScore) return bScore.compareTo(aScore);
          
          final aImportance = a['importance'] ?? 0.0;
          final bImportance = b['importance'] ?? 0.0;
          return bImportance.compareTo(aImportance);
        });

        return suggestions.take(8).toList();
      } else {
        print('Geocoding failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Geocoding strategy error for "$query": $e');
    }
    
    return [];
  }

  String _createDisplayName(String fullAddress) {
    final parts = fullAddress.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    
    if (parts.length <= 2) return fullAddress;
    
    // Take first 2-3 meaningful parts, excluding common geographic terms
    final meaningfulParts = parts.take(4).where((part) => 
      part.length > 2 && 
      !part.toLowerCase().contains('bangladesh') &&
      !part.toLowerCase().contains('dhaka') &&
      !part.toLowerCase().contains('division') &&
      !part.toLowerCase().contains('district') &&
      !part.toLowerCase().contains('thana') &&
      !part.toLowerCase().contains('postal') &&
      !part.toLowerCase().contains('zip')
    ).toList();
    
    if (meaningfulParts.isNotEmpty) {
      final result = meaningfulParts.join(', ');
      return result.length > 60 ? result.substring(0, 60) + '...' : result;
    }
    
    return parts.take(2).join(', ');
  }

  double _calculateRelevanceScore(String query, String displayName, double importance) {
    final queryLower = query.toLowerCase();
    final displayLower = displayName.toLowerCase();
    
    double score = 0.0;
    
    // Exact match gets highest score
    if (displayLower.contains(queryLower)) score += 15.0;
    
    // Word-by-word matching
    final queryWords = queryLower.split(RegExp(r'[,\s]+')).where((word) => word.length > 2).toList();
    for (final word in queryWords) {
      if (displayLower.contains(word)) score += 3.0;
    }
    
    // Importance factor (higher importance = higher score)
    score += importance * 0.2;
    
    // Prefer shorter, more specific names
    if (displayName.length < 40) score += 2.0;
    else if (displayName.length < 60) score += 1.0;
    
    // Bonus for Dhaka-specific locations
    if (displayLower.contains('dhaka') || displayLower.contains('gulshan') || 
        displayLower.contains('banani') || displayLower.contains('dhanmondi') ||
        displayLower.contains('uttara') || displayLower.contains('mirpur')) {
      score += 5.0;
    }
    
    // Bonus for common place types
    if (displayLower.contains('market') || displayLower.contains('mall') ||
        displayLower.contains('hospital') || displayLower.contains('university') ||
        displayLower.contains('station') || displayLower.contains('airport')) {
      score += 3.0;
    }
    
    return score;
  }

  String _extractMainAddressPart(String address) {
    final parts = address.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    
    if (parts.isEmpty) return address;
    
    // Take the first meaningful part
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    } else {
      return parts[0];
    }
  }

  String _simplifyAddress(String address) {
    String simplified = address.trim();
    
    // Remove common suffixes and prefixes
    simplified = simplified.replaceAll(RegExp(r'\b(floor|fl|room|rm|apt|apartment|suite|ste|building|bldg|tower|plaza|mall|center|centre|complex)\b', caseSensitive: false), '');
    
    // Remove specific numbers that might be house numbers
    simplified = simplified.replaceAll(RegExp(r'^\d+\s+'), '');
    
    // Clean up extra spaces and commas
    simplified = simplified.replaceAll(RegExp(r'\s+'), ' ').trim();
    simplified = simplified.replaceAll(RegExp(r',+'), ',').trim();
    
    // Remove trailing commas
    if (simplified.endsWith(',')) {
      simplified = simplified.substring(0, simplified.length - 1).trim();
    }
    
    return simplified;
  }

  void _selectSourceSuggestion(Map<String, dynamic> suggestion) {
    if (suggestion['type'] == 'bus_stop') {
      _sourceController.text = suggestion['name'];
    } else {
      _sourceController.text = suggestion['fullAddress'] ?? suggestion['name'];
    }

    _sourcePoint = LatLng(suggestion['latitude'], suggestion['longitude']);
    if (_mapController != null && _mapReady) {
      _mapController!.move(_sourcePoint!, 15.0);
    }

    if (suggestion['type'] == 'bus_stop') {
      _updateRoute();
    } else {
      _updateRouteForCustomLocation();
    }

    setState(() {
      _showSourceSuggestions = false;
      _sourceSuggestions = [];
    });
  }

  void _selectDestinationSuggestion(Map<String, dynamic> suggestion) {
    if (suggestion['type'] == 'bus_stop') {
      _destinationController.text = suggestion['name'];
    } else {
      _destinationController.text =
          suggestion['fullAddress'] ?? suggestion['name'];
    }

    _destinationPoint = LatLng(suggestion['latitude'], suggestion['longitude']);
    if (_mapController != null && _mapReady) {
      _mapController!.move(_destinationPoint!, 15.0);
    }

    if (suggestion['type'] == 'bus_stop') {
      _updateRoute();
    } else {
      _updateRouteForCustomLocation();
    }

    setState(() {
      _showDestinationSuggestions = false;
      _destinationSuggestions = [];
    });
  }

  @override
  void dispose() {
    _sourceDebounceTimer?.cancel();
    _destinationDebounceTimer?.cancel();
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

  Future<void> _updateRouteForCustomLocation() async {
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

    if (mounted) {
      _showResultsSheetForCustomLocation();
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

        List<Bus> filteredBuses = buses;
        List<Bus> womenOnlyBuses =
            buses.where((bus) => bus.busType == 'women').toList();

        if (_currentUserGender?.toLowerCase() == 'male') {
          filteredBuses = buses.where((bus) => bus.busType != 'women').toList();
        }

        // Check if all regular buses are halfway full and suggest women-only buses
        if (_currentUserGender?.toLowerCase() == 'female' &&
            filteredBuses.isNotEmpty &&
            womenOnlyBuses.isNotEmpty) {
          _checkAndSuggestWomenOnlyBuses(filteredBuses, womenOnlyBuses);
        }

        setState(() {
          _availableBuses = filteredBuses;
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

  void _checkAndSuggestWomenOnlyBuses(
      List<Bus> regularBuses, List<Bus> womenOnlyBuses) async {
    // Check if all regular buses are at least halfway full by checking individual bus data
    bool allRegularBusesHalfFull = true;

    for (final bus in regularBuses) {
      try {
        final individualBuses =
            await IndividualBusService.getIndividualBuses(bus.id);
        if (individualBuses['success'] && individualBuses['data'].isNotEmpty) {
          final List<IndividualBus> buses = individualBuses['data'];
          // Check if any individual bus on this route has available capacity
          bool hasAvailableCapacity = buses.any((individualBus) =>
              individualBus.currentPassengerCount <
              (individualBus.totalPassengerCapacity * 0.8));

          if (hasAvailableCapacity) {
            allRegularBusesHalfFull = false;
            break;
          }
        }
      } catch (e) {
        // If we can't check capacity, assume bus is not full
        allRegularBusesHalfFull = false;
        break;
      }
    }

    if (allRegularBusesHalfFull && womenOnlyBuses.isNotEmpty) {
      // Show suggestion dialog after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showWomenOnlySuggestionDialog(womenOnlyBuses, busInfoId: null);
        }
      });
    }
  }

  void _showWomenOnlySuggestionDialog(List<Bus> womenOnlyBuses,
      {String? busInfoId}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.woman,
                    size: 48,
                    color: Colors.pink[600],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Better Option Available!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Regular buses are getting crowded. Consider women-only buses for a more comfortable ride.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.grey[700],
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Continue with regular',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showWomenOnlyBusesDialog(womenOnlyBuses,
                              busInfoId: busInfoId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Show women-only',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWomenOnlyBusesDialog(List<dynamic> womenOnlyBuses,
      {String? busInfoId}) {
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Women-Only Buses',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.pink[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.woman,
                                size: 14,
                                color: Colors.pink[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Exclusive for female passengers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.pink[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    itemCount: womenOnlyBuses.length,
                    itemBuilder: (context, index) {
                      final bus = womenOnlyBuses[index];
                      // Handle both Bus and IndividualBus types
                      double distance = 0.0;
                      double totalFare = 0.0;

                      if (bus is Bus) {
                        distance = _calculateRouteDistance(bus);
                        totalFare = bus.calculateFare(distance);
                      } else if (bus is IndividualBus && busInfoId != null) {
                        // For IndividualBus, we need to get the route info
                        final busInfo = _getBusInfoById(busInfoId);
                        if (busInfo != null) {
                          distance = _calculateRouteDistance(busInfo);
                          totalFare = busInfo.calculateFare(distance);
                        }
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.pink[100]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bus.busName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.pink[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Women Only',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.pink[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.straighten,
                                          color: Colors.blue[600],
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '${distance.toStringAsFixed(1)} km',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          color: Colors.green[600],
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '৳${totalFare.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _toggleIndividualBuses(bus.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions_bus, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Show Individual Buses',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
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
                // Show women-only bus suggestion for female users
                if (_currentUserGender?.toLowerCase() == 'female' &&
                    _availableBuses.any((bus) => bus.busType != 'women') &&
                    _availableBuses.any((bus) => bus.busType == 'women'))
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pink[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.woman,
                          color: Colors.pink[600],
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Women-Only Buses Available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.pink[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Consider women-only buses for a more comfortable ride',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.pink[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final womenOnlyBuses = _availableBuses
                                .where((bus) => bus.busType == 'women')
                                .toList();
                            Navigator.of(context).pop();
                            _showWomenOnlyBusesDialog(womenOnlyBuses,
                                busInfoId: null);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'View',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

                                    final isWomenBus = bus.busType == 'women';
                                    final isGreyedOut =
                                        _currentUserGender?.toLowerCase() ==
                                                'male' &&
                                            isWomenBus;

                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isGreyedOut
                                            ? Colors.grey[100]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: isGreyedOut
                                                ? Colors.grey[300]!
                                                : Colors.grey[100]!),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha:
                                                    isGreyedOut ? 0.03 : 0.06),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  bus.busName,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: isGreyedOut
                                                        ? Colors.grey[500]
                                                        : Colors.grey[900],
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: isGreyedOut
                                                          ? Colors.grey[200]
                                                          : Colors.blue[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: isGreyedOut
                                                            ? Colors.grey[400]!
                                                            : Colors
                                                                .transparent,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.info_outline,
                                                        color: isGreyedOut
                                                            ? Colors.grey[500]
                                                            : Colors.blue[600],
                                                        size: 16,
                                                      ),
                                                      onPressed: () {
                                                        if (_currentUserGender
                                                                    ?.toLowerCase() ==
                                                                'male' &&
                                                            bus.busType ==
                                                                'women') {
                                                          _showWomenBusPopup();
                                                        } else {
                                                          _toggleIndividualBuses(
                                                              bus.id);
                                                        }
                                                      },
                                                      tooltip: isGreyedOut
                                                          ? 'Women only bus - Not available for male passengers'
                                                          : 'Show individual buses',
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          BoxConstraints(),
                                                      style:
                                                          IconButton.styleFrom(
                                                        disabledForegroundColor:
                                                            Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: isGreyedOut
                                                          ? Colors.grey[200]
                                                          : Colors.green[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: isGreyedOut
                                                            ? Colors.grey[400]!
                                                            : Colors
                                                                .transparent,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.route,
                                                        color: isGreyedOut
                                                            ? Colors.grey[500]
                                                            : Colors.green[600],
                                                        size: 16,
                                                      ),
                                                      onPressed: () {
                                                        if (_currentUserGender
                                                                    ?.toLowerCase() ==
                                                                'male' &&
                                                            bus.busType ==
                                                                'women') {
                                                          _showWomenBusPopup();
                                                        } else {
                                                          _showStopsDialog(bus);
                                                        }
                                                      },
                                                      tooltip: isGreyedOut
                                                          ? 'Women only bus - Not available for male passengers'
                                                          : 'Show stops',
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          BoxConstraints(),
                                                      style:
                                                          IconButton.styleFrom(
                                                        disabledForegroundColor:
                                                            Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            children: [
                                              if (isWomenBus)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.pink[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color:
                                                            Colors.pink[200]!),
                                                  ),
                                                  child: Text(
                                                    'Women Only',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.pink[700],
                                                    ),
                                                  ),
                                                ),
                                              if (isWomenBus)
                                                SizedBox(width: 12),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isGreyedOut
                                                      ? Colors.grey[100]
                                                      : Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: isGreyedOut
                                                          ? Colors.grey[300]!
                                                          : Colors.blue[200]!),
                                                ),
                                                child: Text(
                                                  '${distance.toStringAsFixed(1)} km',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isGreyedOut
                                                        ? Colors.grey[500]
                                                        : Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isGreyedOut
                                                      ? Colors.grey[100]
                                                      : Colors.green[50],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: isGreyedOut
                                                          ? Colors.grey[300]!
                                                          : Colors.green[200]!),
                                                ),
                                                child: Text(
                                                  '৳${totalFare.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: isGreyedOut
                                                        ? Colors.grey[500]
                                                        : Colors.green[700],
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
        );
      },
    );
  }

  void _showResultsSheetForCustomLocation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.25,
          maxChildSize: 0.4,
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
                        'Custom Location',
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
                const SizedBox(height: 16),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This location is not served by public buses. Use RideShare to find a ride to your destination.',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    if (_mapController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                        onPressed: () async {
                          final query = _sourceController.text.trim();
                          if (query.isEmpty) return;

                          final stop = _allBusStops.firstWhere(
                            (s) => s.name.toLowerCase() == query.toLowerCase(),
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
                          } else {
                            final geocodingSuggestions =
                                await _getGeocodingSuggestions(query);
                            if (geocodingSuggestions.isNotEmpty) {
                              final location = geocodingSuggestions.first;
                              _sourcePoint = LatLng(
                                  location['latitude'], location['longitude']);
                              _sourceController.text =
                                  location['fullAddress'] ?? location['name'];
                              if (_mapController != null && _mapReady) {
                                _mapController!.move(_sourcePoint!, 15.0);
                              }
                              _updateRouteForCustomLocation();
                            }
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
                    onSubmitted: (_) async {
                      final query = _sourceController.text.trim();
                      if (query.isEmpty) return;

                      final stop = _allBusStops.firstWhere(
                        (s) => s.name.toLowerCase() == query.toLowerCase(),
                        orElse: () =>
                            BusStop(name: '', latitude: 0.0, longitude: 0.0),
                      );
                      if (stop.name.isNotEmpty) {
                        _sourcePoint = LatLng(stop.latitude, stop.longitude);
                        if (_mapController != null && _mapReady) {
                          _mapController!.move(_sourcePoint!, 15.0);
                        }
                        _updateRoute();
                      } else {
                        final geocodingSuggestions =
                            await _getGeocodingSuggestions(query);
                        if (geocodingSuggestions.isNotEmpty) {
                          final location = geocodingSuggestions.first;
                          _sourcePoint = LatLng(
                              location['latitude'], location['longitude']);
                          _sourceController.text =
                              location['fullAddress'] ?? location['name'];
                          if (_mapController != null && _mapReady) {
                            _mapController!.move(_sourcePoint!, 15.0);
                          }
                          _updateRouteForCustomLocation();
                        }
                      }
                    },
                  ),
                  if (_showSourceSuggestions && _sourceSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _sourceSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _sourceSuggestions[index];
                          final isBusStop = suggestion['type'] == 'bus_stop';
                          final isExactMatch = suggestion['isExactMatch'] == true;
                          
                          return GestureDetector(
                            onTap: () => _selectSourceSuggestion(suggestion),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isExactMatch ? Colors.blue[50] : Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isBusStop ? Colors.blue[100] : Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isBusStop ? Icons.directions_bus : Icons.location_on,
                                    color: isBusStop ? Colors.blue[700] : Colors.green[700],
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        suggestion['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isExactMatch ? FontWeight.w600 : FontWeight.w500,
                                          color: isExactMatch ? Colors.blue[800] : Colors.grey[800],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isExactMatch)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Exact',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (suggestion['type'] == 'location' && suggestion['fullAddress'] != null)
                                      Text(
                                        suggestion['fullAddress']!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (suggestion['type'] == 'location' && suggestion['placeType'] != null)
                                      Container(
                                        margin: EdgeInsets.only(top: 2),
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          suggestion['placeType']!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
                        onPressed: () async {
                          final query = _destinationController.text.trim();
                          if (query.isEmpty) return;

                          final stop = _allBusStops.firstWhere(
                            (s) => s.name.toLowerCase() == query.toLowerCase(),
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
                          } else {
                            final geocodingSuggestions =
                                await _getGeocodingSuggestions(query);
                            if (geocodingSuggestions.isNotEmpty) {
                              final location = geocodingSuggestions.first;
                              _destinationPoint = LatLng(
                                  location['latitude'], location['longitude']);
                              _destinationController.text =
                                  location['fullAddress'] ?? location['name'];
                              if (_mapController != null && _mapReady) {
                                _mapController!.move(_destinationPoint!, 15.0);
                              }
                              _updateRouteForCustomLocation();
                            }
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
                    onSubmitted: (_) async {
                      final query = _destinationController.text.trim();
                      if (query.isEmpty) return;

                      final stop = _allBusStops.firstWhere(
                        (s) => s.name.toLowerCase() == query.toLowerCase(),
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
                      } else {
                        final geocodingSuggestions =
                            await _getGeocodingSuggestions(query);
                        if (geocodingSuggestions.isNotEmpty) {
                          final location = geocodingSuggestions.first;
                          _destinationPoint = LatLng(
                              location['latitude'], location['longitude']);
                          _destinationController.text =
                              location['fullAddress'] ?? location['name'];
                          if (_mapController != null && _mapReady) {
                            _mapController!.move(_destinationPoint!, 15.0);
                          }
                          _updateRouteForCustomLocation();
                        }
                      }
                    },
                  ),
                  if (_showDestinationSuggestions &&
                      _destinationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _destinationSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _destinationSuggestions[index];
                          final isBusStop = suggestion['type'] == 'bus_stop';
                          final isExactMatch = suggestion['isExactMatch'] == true;
                          
                          return GestureDetector(
                            onTap: () => _selectDestinationSuggestion(suggestion),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isExactMatch ? Colors.blue[50] : Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isBusStop ? Colors.blue[100] : Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isBusStop ? Icons.directions_bus : Icons.location_on,
                                    color: isBusStop ? Colors.blue[700] : Colors.green[700],
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        suggestion['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isExactMatch ? FontWeight.w600 : FontWeight.w500,
                                          color: isExactMatch ? Colors.blue[800] : Colors.grey[800],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isExactMatch)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Exact',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (suggestion['type'] == 'location' && suggestion['fullAddress'] != null)
                                      Text(
                                        suggestion['fullAddress']!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (suggestion['type'] == 'location' && suggestion['placeType'] != null)
                                      Container(
                                        margin: EdgeInsets.only(top: 2),
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          suggestion['placeType']!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
