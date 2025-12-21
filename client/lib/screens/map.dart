import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../utils/app_theme.dart';
import '../services/auth_service.dart';
import '../services/fav_bus_service.dart';
import '../services/individual_bus_service.dart';
import '../services/trip_history_service.dart';
import '../services/stops_service.dart' show StopsService, StopData;
import '../services/fare_service.dart';
import '../services/rating_service.dart';
import '../models/bus.dart';
import '../models/individual_bus.dart';
import '../utils/distance_calculator.dart' as distance_calc;
import 'search.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.onOpenRideshare, this.onBoarded});

  final Function(String, String)? onOpenRideshare;
  final Function(IndividualBus, Bus, String, String, double, double)? onBoarded;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
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
  final Map<String, bool> _tripRecordsCreated = {}; // Track created trip records by busInfoId
  final Map<String, double> _busDistances = {}; // Cache for bus route distances
  final Map<String, double> _busRatings = {}; // Cache for bus ratings

  List<BusStop> _allBusStops = [];

  DraggableScrollableController? _bottomSheetController;
  late AnimationController _polylineAnimationController;

  static const LatLng dhakaCenter = LatLng(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _getCurrentUserId();
    _loadAllBusStops();
    _loadBusRatings();
    _bottomSheetController = DraggableScrollableController();
    _polylineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _bottomSheetController?.dispose();
    _polylineAnimationController.dispose();
    super.dispose();
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
                                // Line 1: Individual bus name, running status, passenger count
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            bus.busCode,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 20,
                                              color: Colors.grey[900],
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(bus.status),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              bus.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (bus.busType == 'women') ...[
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.pink[400],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'WOMEN',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people,
                                          color: bus.currentPassengerCount >=
                                                  bus.totalPassengerCapacity
                                              ? Colors.red[600]
                                              : bus.currentPassengerCount >=
                                                      (bus.totalPassengerCapacity *
                                                          0.8)
                                                  ? Colors.orange[600]
                                                  : Colors.blue[600],
                                          size: 20,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '${bus.currentPassengerCount}/${bus.totalPassengerCapacity}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
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
                                  ],
                                ),
                                SizedBox(height: 16),
                                // Line 2: Big Board button covering whole width
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: AnimatedSwitcher(
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
                                              key: ValueKey('board_${bus.id}'),
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
                                                minimumSize: Size(double.infinity, 56),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                                elevation: 2,
                                              ),
                                              child: Text(
                                                bus.currentPassengerCount >=
                                                        bus
                                                            .totalPassengerCapacity
                                                    ? 'FULL'
                                                    : bus.currentPassengerCount >=
                                                            (bus.totalPassengerCapacity *
                                                                0.8)
                                                        ? 'NEARLY FULL'
                                                        : 'BOARD',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
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
                                              minimumSize: Size(double.infinity, 56),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                            child: Text(
                                              'END TRIP',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                // Line 3: Distance and time
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.straighten,
                                              color: Colors.green[600],
                                              size: 22,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '${_calculateDistanceFromSource(bus).toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.orange[600],
                                              size: 22,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              _calculateETA(bus),
                                              style: TextStyle(
                                                fontSize: 16,
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

      // Call board API to mark user as boarding
      final token = await AuthService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication required'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/board');
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
        final data = json.decode(response.body);
        if (data['success']) {
          // Mark as boarded
          setState(() {
            _boardedBuses[busId] = true;
          });

      Navigator.of(context).pop();

          // Notify parent (NavScreen) that user has boarded
          if (widget.onBoarded != null) {
            widget.onBoarded!(
              individualBus,
              busInfo,
              source,
              destination,
              distance,
              fare,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully boarded! Click "End Trip" when you reach your destination.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to board bus'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to board bus'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
        ),
      );
      }
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
    // Prevent duplicate trip record creation
    if (_tripRecordsCreated[busInfoId] == true) {
      print('Trip record already created for bus $busInfoId, skipping duplicate');
      return;
    }

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
            setState(() {
              _tripRecordsCreated[busInfoId] = true;
            });
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

  void _showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SOS Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning,
                    size: 48,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Emergency Services',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Emergency Options
                _buildEmergencyOption(
                  icon: Icons.local_hospital,
                  label: 'Ambulance',
                  color: Colors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    _callEmergency('999', 'Ambulance');
                  },
                ),
                const SizedBox(height: 12),
                _buildEmergencyOption(
                  icon: Icons.local_police,
                  label: 'Police',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    _callEmergency('999', 'Police');
                  },
                ),
                const SizedBox(height: 12),
                _buildEmergencyOption(
                  icon: Icons.fire_truck,
                  label: 'Fire',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.of(context).pop();
                    _callEmergency('999', 'Fire');
                  },
                ),
                const SizedBox(height: 12),
                _buildEmergencyOption(
                  icon: Icons.share_location,
                  label: 'Share Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).pop();
                    _shareLocation();
                  },
                ),
                const SizedBox(height: 16),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
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

  Widget _buildEmergencyOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _callEmergency(String number, String service) {
    // TODO: Implement actual emergency call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $service: $number'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    // You can use url_launcher package to make actual calls:
    // final uri = Uri.parse('tel:$number');
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    // }
  }

  void _shareLocation() {
    // Get current location or use source/destination
    String locationText = 'My current location';
    
    if (_sourcePoint != null) {
      locationText = 'Source: ${_sourcePoint!.latitude}, ${_sourcePoint!.longitude}';
    } else if (_destinationPoint != null) {
      locationText = 'Destination: ${_destinationPoint!.latitude}, ${_destinationPoint!.longitude}';
    }
    
    // TODO: Implement actual location sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing location: $locationText'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    // You can use share_plus package to share location:
    // Share.share('My location: https://maps.google.com/?q=$lat,$lng');
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
      // First sort by favorites
      final aFavorited = _favoriteStatus[a.id] ?? false;
      final bFavorited = _favoriteStatus[b.id] ?? false;

      if (aFavorited && !bFavorited) return -1;
      if (!aFavorited && bFavorited) return 1;
      
      // Then sort by rating (highest first)
      final aRating = _busRatings[a.id] ?? 0.0;
      final bRating = _busRatings[b.id] ?? 0.0;
      return bRating.compareTo(aRating); // Highest rating first
    });
    return sortedBuses;
  }
  
  Future<void> _loadBusRatings() async {
    try {
      final result = await RatingService.getAllBusRatings();
      if (result['success'] && result['data'] != null) {
        final ratingsMap = result['data'] as Map<String, dynamic>;
        setState(() {
          _busRatings.clear();
          ratingsMap.forEach((busId, ratingData) {
            if (ratingData is Map && ratingData['averageRating'] != null) {
              final rating = (ratingData['averageRating'] is num)
                  ? ratingData['averageRating'].toDouble()
                  : double.tryParse(ratingData['averageRating'].toString()) ?? 0.0;
              // Store with cleaned busId (trim whitespace)
              final cleanBusId = busId.toString().trim();
              _busRatings[cleanBusId] = rating;
            }
          });
        });
      }
    } catch (e) {
      print('Error loading bus ratings in map: $e');
    }
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

  Future<void> _navigateToSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );

    if (result != null && result is Map) {
      final source = result['source'] as String?;
      final destination = result['destination'] as String?;
      final sourceCoords = result['sourceCoordinates'] as Map<String, double>?;
      final destCoords = result['destinationCoordinates'] as Map<String, double>?;
      
      if (source != null && destination != null) {
        setState(() {
          _sourceController.text = source;
          _destinationController.text = destination;
        });
        
        // Process search results with provided coordinates
        await _processSearchResults(source, destination, sourceCoords, destCoords);
      }
    }
  }

  Future<void> _processSearchResults(
    String source,
    String destination,
    Map<String, double>? sourceCoords,
    Map<String, double>? destCoords,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      LatLng? sourcePoint;
      LatLng? destinationPoint;

      // Use provided coordinates if available (from search screen)
      if (sourceCoords != null && sourceCoords['lat'] != null && sourceCoords['lon'] != null) {
        sourcePoint = LatLng(sourceCoords['lat']!, sourceCoords['lon']!);
        print('Using provided source coordinates: ${sourcePoint.latitude}, ${sourcePoint.longitude}');
      } else {
        // First, try to get coordinates from stops collection (fastest)
        final stopData = await StopsService.getStopCoordinates(source);
        if (stopData != null) {
          sourcePoint = LatLng(stopData.lat, stopData.lng);
          print('Found source in stops collection: ${sourcePoint.latitude}, ${sourcePoint.longitude}');
        } else {
          // Fallback: try to find coordinates from local bus stops cache
          sourcePoint = _findBusStopCoordinates(source);
          
          // If still not found, geocode
          if (sourcePoint == null) {
            print('Geocoding source: $source');
            final geocodedCoords = await _geocodeAddress(source);
            if (geocodedCoords != null) {
              sourcePoint = LatLng(geocodedCoords['lat']!, geocodedCoords['lon']!);
              print('Geocoded source coordinates: ${sourcePoint.latitude}, ${sourcePoint.longitude}');
            }
          }
        }
      }

      // Use provided coordinates if available (from search screen)
      if (destCoords != null && destCoords['lat'] != null && destCoords['lon'] != null) {
        destinationPoint = LatLng(destCoords['lat']!, destCoords['lon']!);
        print('Using provided destination coordinates: ${destinationPoint.latitude}, ${destinationPoint.longitude}');
      } else {
        // First, try to get coordinates from stops collection (fastest)
        final stopData = await StopsService.getStopCoordinates(destination);
        if (stopData != null) {
          destinationPoint = LatLng(stopData.lat, stopData.lng);
          print('Found destination in stops collection: ${destinationPoint.latitude}, ${destinationPoint.longitude}');
        } else {
          // Fallback: try to find coordinates from local bus stops cache
          destinationPoint = _findBusStopCoordinates(destination);
          
          // If still not found, geocode
          if (destinationPoint == null) {
            print('Geocoding destination: $destination');
            final geocodedCoords = await _geocodeAddress(destination);
            if (geocodedCoords != null) {
              destinationPoint = LatLng(geocodedCoords['lat']!, geocodedCoords['lon']!);
              print('Geocoded destination coordinates: ${destinationPoint.latitude}, ${destinationPoint.longitude}');
            }
          }
        }
      }

      if (sourcePoint != null && destinationPoint != null) {
        setState(() {
          _sourcePoint = sourcePoint;
          _destinationPoint = destinationPoint;
        });
        
        // Draw route and show bus list
        await _updateRoute();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find coordinates for source or destination. Please try selecting from suggestions.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing search results: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing locations: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  LatLng? _findBusStopCoordinates(String query) {
    final queryLower = query.toLowerCase().trim();
    for (final stop in _allBusStops) {
      if (stop.name.toLowerCase() == queryLower ||
          stop.name.toLowerCase().contains(queryLower) ||
          queryLower.contains(stop.name.toLowerCase())) {
        return LatLng(stop.latitude, stop.longitude);
      }
    }
    return null;
  }

  Future<Map<String, double>?> _geocodeAddress(String query) async {
    try {
      print('Geocoding address: "$query"');

      // Use backend geocoding endpoint
      final uri = Uri.parse('${AuthService.baseUrl}/api/geocoding/geocode').replace(
        queryParameters: {'q': query},
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10), // Reduced timeout to 10 seconds
        onTimeout: () {
          print('Geocoding request timed out for: "$query"');
          throw TimeoutException('Geocoding request timed out', const Duration(seconds: 10));
        },
      );

      if (response.statusCode != 200) {
        print('Geocoding failed with status: ${response.statusCode}');
        return null;
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      if (!responseData['success'] || responseData['data'] == null) {
        print('Geocoding failed: ${responseData['message'] ?? 'Unknown error'}');
        return null;
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final lat = double.tryParse(data['lat']?.toString() ?? '');
      final lon = double.tryParse(data['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        print('Invalid coordinates in response');
        return null;
      }

      // Validate coordinates are reasonable for Bangladesh
      if (lat >= 20.0 && lat <= 27.0 && lon >= 88.0 && lon <= 93.0) {
        print('Geocoding success for "$query": lat=$lat, lon=$lon');
        print('Detailed address: ${data['display_name'] ?? 'N/A'}');
        return {'lat': lat, 'lon': lon};
      } else {
        print('Warning: Coordinates outside Bangladesh bounds: lat=$lat, lon=$lon');
        // Still return the coordinates as they might be close
        return {'lat': lat, 'lon': lon};
      }
    } catch (e) {
      print('Geocoding error for "$query": $e');
      return null;
    }
  }

  Future<void> _precalculateBusDistances(List<Bus> buses) async {
    if (_sourcePoint == null || _destinationPoint == null) return;
    
    final source = _sourceController.text.trim();
    final destination = _destinationController.text.trim();
    
    if (source.isEmpty || destination.isEmpty) return;

    // Try to get distance from fares collection first
    try {
      final user = await AuthService.getUser();
      final fareResult = await FareService.getFare(
        userId: user?.id,
        source: source,
        destination: destination,
      );

      if (fareResult['success'] && fareResult['data'] != null) {
        final fareData = fareResult['data'] as Map<String, dynamic>;
        final roadDistance = (fareData['distance'] as num).toDouble();
        
        // Apply to all buses
        for (final bus in buses) {
          final cacheKey = '${bus.id}_${source}_${destination}';
          if (mounted) {
            setState(() {
              _busDistances[cacheKey] = roadDistance;
            });
          }
        }
        return;
      }
    } catch (e) {
      print('Error getting fare from collection: $e');
    }

    // If not in fares, calculate road distance using backend
    try {
      final distanceResult = await FareService.calculateRoadDistance(
        sourceLat: _sourcePoint!.latitude,
        sourceLon: _sourcePoint!.longitude,
        destLat: _destinationPoint!.latitude,
        destLon: _destinationPoint!.longitude,
      );

      if (distanceResult['success'] && distanceResult['data'] != null) {
        final roadDistance = (distanceResult['data']['distance'] as num).toDouble();
        
        // Apply to all buses
        for (final bus in buses) {
          final cacheKey = '${bus.id}_${source}_${destination}';
          if (mounted) {
            setState(() {
              _busDistances[cacheKey] = roadDistance;
            });
          }
        }
      }
    } catch (e) {
      print('Error calculating road distance: $e');
    }
  }

  Future<void> _updateRoute() async {
    if (_sourcePoint == null || _destinationPoint == null) return;

    setState(() {
      _isLoading = true;
    });

    // First fetch available buses to get bus route information
    await _fetchAvailableBuses();

    // Draw polyline based on bus stops if buses are available
    if (_availableBuses.isNotEmpty) {
      // Use the first bus's route (all buses on same route should have similar stops)
      final bus = _availableBuses.first;
      
      // Find source and destination stops in the bus route
      final sourceStopIndex = bus.stops.indexWhere(
        (stop) => stop.name.toLowerCase() == _sourceController.text.trim().toLowerCase(),
      );
      final destStopIndex = bus.stops.indexWhere(
        (stop) => stop.name.toLowerCase() == _destinationController.text.trim().toLowerCase(),
      );

      if (sourceStopIndex != -1 && destStopIndex != -1 && sourceStopIndex < destStopIndex) {
        // Get stops between source and destination
        final routeStops = bus.stops.sublist(sourceStopIndex, destStopIndex + 1);
        
        // Create route points from bus stops
        final routePoints = routeStops.map((stop) {
          return LatLng(stop.latitude, stop.longitude);
        }).toList();

        setState(() {
          _routePoints = routePoints;
        });

        _fitMapToRoute();
      } else {
        // Fallback: use direct route if stops not found in bus route
        _drawDirectRoute();
      }
    } else {
      // No buses available, draw direct route
      _drawDirectRoute();
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      _showResultsSheet();
    }
  }

  Future<void> _drawDirectRoute() async {
    if (_sourcePoint == null || _destinationPoint == null) return;

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
          _busDistances.clear(); // Clear distance cache when buses change
        });
        await _loadFavoriteStatuses();
        await _loadBusRatings(); // Reload ratings when buses change
        
        // Pre-calculate distances for all buses
        if (_sourcePoint != null && _destinationPoint != null) {
          _precalculateBusDistances(filteredBuses);
        }
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

    // Check cache first
    final cacheKey = '${bus.id}_${_sourceController.text.trim()}_${_destinationController.text.trim()}';
    if (_busDistances.containsKey(cacheKey)) {
      return _busDistances[cacheKey]!;
    }

    // Find source and destination stop coordinates
    final sourceStopIndex = bus.stops.indexWhere(
      (stop) =>
          stop.name.toLowerCase() ==
          _sourceController.text.trim().toLowerCase(),
    );
    final destStopIndex = bus.stops.indexWhere(
      (stop) =>
          stop.name.toLowerCase() ==
          _destinationController.text.trim().toLowerCase(),
    );

    // If stops not found, use source/destination points directly
    if (sourceStopIndex == -1 || destStopIndex == -1) {
      // Use the source and destination points from the map
      final distance = distance_calc.DistanceCalculator.calculateDistance(
        _sourcePoint!.latitude,
        _sourcePoint!.longitude,
        _destinationPoint!.latitude,
        _destinationPoint!.longitude,
      );
      _busDistances[cacheKey] = distance;
      return distance;
    }

    // Get coordinates from stops
    final sourceStop = bus.stops[sourceStopIndex];
    final destStop = bus.stops[destStopIndex];

    // Use road distance calculation (same as rideshare/search)
    // For now, use Haversine but we'll update this to use backend
    final distance = distance_calc.DistanceCalculator.calculateDistance(
      sourceStop.latitude,
      sourceStop.longitude,
      destStop.latitude,
      destStop.longitude,
    );

    // Cache the result
    _busDistances[cacheKey] = distance;
    
    // Try to get road distance from fares collection or backend (async, don't wait)
    _updateRouteDistanceWithRoadDistance(
      bus.id,
      sourceStop.latitude,
      sourceStop.longitude,
      destStop.latitude,
      destStop.longitude,
      cacheKey,
    );

    return distance;
  }

  Future<void> _updateRouteDistanceWithRoadDistance(
    String busId,
    double sourceLat,
    double sourceLon,
    double destLat,
    double destLon,
    String cacheKey,
  ) async {
    try {
      // First try to get from fares collection
      final source = _sourceController.text.trim();
      final destination = _destinationController.text.trim();
      
      final user = await AuthService.getUser();
      final fareResult = await FareService.getFare(
        userId: user?.id,
        source: source,
        destination: destination,
      );

      if (fareResult['success'] && fareResult['data'] != null) {
        final fareData = fareResult['data'] as Map<String, dynamic>;
        final roadDistance = (fareData['distance'] as num).toDouble();
        
        if (mounted) {
          setState(() {
            _busDistances[cacheKey] = roadDistance;
          });
        }
        return;
      }

      // If not in fares, calculate road distance using backend
      final distanceResult = await FareService.calculateRoadDistance(
        sourceLat: sourceLat,
        sourceLon: sourceLon,
        destLat: destLat,
        destLon: destLon,
      );

      if (distanceResult['success'] && distanceResult['data'] != null) {
        final roadDistance = (distanceResult['data']['distance'] as num).toDouble();
        
        if (mounted) {
          setState(() {
            _busDistances[cacheKey] = roadDistance;
          });
        }
      }
    } catch (e) {
      print('Error updating route distance: $e');
      // Keep the cached Haversine distance
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            controller: _bottomSheetController,
            initialChildSize: 0.35,
            minChildSize: 0.25,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Clickable header area for web compatibility
                  GestureDetector(
                    onTap: () {
                      if (_bottomSheetController != null && _bottomSheetController!.isAttached) {
                        final currentSize = _bottomSheetController!.size;
                        final isExpanded = currentSize >= 0.7;
                        _bottomSheetController!.animateTo(
                          isExpanded ? 0.25 : 0.8,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Title with expand/collapse indicator
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.directions_bus_filled,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Available Buses',
                                      style: AppTheme.heading3Dark(context).copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.accentGreen,
                                        AppTheme.accentGreen.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentGreen.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).maybePop();
                                        if (widget.onOpenRideshare != null) {
                                          widget.onOpenRideshare!(
                                            _sourceController.text.trim(),
                                            _destinationController.text.trim(),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.directions_car_rounded, size: 18, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text(
                                              'RideShare',
                                              style: AppTheme.labelLarge.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
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
                        ],
                      ),
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading buses...',
                                  style: AppTheme.bodyMediumDark(context).copyWith(
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _busesError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 48,
                                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _busesError!,
                                      style: AppTheme.bodyMediumDark(context).copyWith(
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _availableBuses.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.directions_bus_outlined,
                                            size: 48,
                                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No buses available',
                                          style: AppTheme.heading4Dark(context).copyWith(
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Try adjusting your route',
                                          style: AppTheme.bodyMediumDark(context).copyWith(
                                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.only(bottom: 20),
                                    itemCount: _getSortedBuses().length,
                                    itemBuilder: (context, index) {
                                    final bus = _getSortedBuses()[index];
                                    final busIdStr = bus.id.toString().trim();
                                    final busRating = _busRatings[busIdStr] ?? 0.0;
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
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 3),
                                      decoration: AppTheme.modernCardDecorationDark(
                                        context,
                                        color: isGreyedOut
                                            ? (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100])
                                            : (isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            if (_currentUserGender?.toLowerCase() == 'male' && bus.busType == 'women') {
                                              _showWomenBusPopup();
                                            } else {
                                              _toggleIndividualBuses(bus.id);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(28),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        gradient: isGreyedOut
                                                            ? LinearGradient(
                                                                colors: [
                                                                  Colors.grey[400]!,
                                                                  Colors.grey[500]!,
                                                                ],
                                                              )
                                                            : AppTheme.primaryGradient,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.directions_bus_filled,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            bus.busName,
                                                            style: AppTheme.heading4Dark(context).copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: isGreyedOut
                                                                  ? (isDark ? AppTheme.darkTextTertiary : Colors.grey[500])
                                                                  : null,
                                                            ),
                                                          ),
                                                          if (bus.routeNumber != null) ...[
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              'Route: ${bus.routeNumber}',
                                                              style: AppTheme.bodySmall.copyWith(
                                                                color: isGreyedOut
                                                                    ? (isDark ? AppTheme.darkTextTertiary : Colors.grey[500])
                                                                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: isGreyedOut
                                                            ? (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[200])
                                                            : (isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Icon(
                                                        Icons.route_rounded,
                                                        color: isGreyedOut
                                                            ? (isDark ? AppTheme.darkTextTertiary : Colors.grey[500])
                                                            : AppTheme.accentGreen,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    if (isWomenBus)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.pink[400]!,
                                                              Colors.pink[600]!,
                                                            ],
                                                          ),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.woman_rounded, color: Colors.white, size: 14),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Women Only',
                                                              style: AppTheme.labelSmall.copyWith(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: isGreyedOut
                                                            ? (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[200])
                                                            : (isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: isGreyedOut
                                                              ? (isDark ? AppTheme.darkBorder : Colors.grey[300]!)
                                                              : AppTheme.primaryBlue.withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${distance.toStringAsFixed(1)} km',
                                                            style: AppTheme.heading4Dark(context).copyWith(
                                                              color: isGreyedOut
                                                                  ? (isDark ? AppTheme.darkTextTertiary : Colors.grey[500])
                                                                  : AppTheme.primaryBlue,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: isGreyedOut
                                                            ? LinearGradient(
                                                                colors: [
                                                                  Colors.grey[400]!,
                                                                  Colors.grey[500]!,
                                                                ],
                                                              )
                                                            : LinearGradient(
                                                                colors: [
                                                                  AppTheme.accentGreen,
                                                                  AppTheme.accentGreen.withOpacity(0.8),
                                                                ],
                                                              ),
                                                        borderRadius: BorderRadius.circular(10),
                                                        boxShadow: isGreyedOut
                                                            ? null
                                                            : [
                                                                BoxShadow(
                                                                  color: AppTheme.accentGreen.withOpacity(0.3),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                              ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Text('৳', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            totalFare.toStringAsFixed(0),
                                                            style: AppTheme.heading4Dark(context).copyWith(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: isGreyedOut
                                                            ? LinearGradient(
                                                                colors: [
                                                                  Colors.grey[400]!,
                                                                  Colors.grey[500]!,
                                                                ],
                                                              )
                                                            : LinearGradient(
                                                                colors: [
                                                                  AppTheme.primaryBlue,
                                                                  AppTheme.primaryBlueLight,
                                                                ],
                                                              ),
                                                        borderRadius: BorderRadius.circular(10),
                                                        boxShadow: isGreyedOut
                                                            ? null
                                                            : [
                                                                BoxShadow(
                                                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                              ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.star_rounded,
                                                            color: Colors.white,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            busRating > 0 
                                                                ? busRating.toStringAsFixed(1)
                                                                : '4.0',
                                                            style: AppTheme.heading4Dark(context).copyWith(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
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
          ),
        );
      },
    );
  }

  void _showResultsSheetForCustomLocation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.25,
          maxChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Clickable header area for web compatibility
                GestureDetector(
                  onTap: () {
                    // Note: This sheet uses a different controller context
                    // For web, we'll rely on the drag handle being more visible
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
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
                      ],
                    ),
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
    });
    if (_mapController != null && _mapReady) {
      _mapController!.move(dhakaCenter, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? AppTheme.darkSurface : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    if (_mapController == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
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
              onTap: (tapPosition, point) {
                // Collapse bottom sheet to minimum size when map is tapped
                if (_bottomSheetController != null && _bottomSheetController!.isAttached) {
                  _bottomSheetController!.animateTo(
                    0.25, // minChildSize
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              if (_routePoints.isNotEmpty)
                AnimatedBuilder(
                  animation: _polylineAnimationController,
                  builder: (context, child) {
                    final animationValue = _polylineAnimationController.value;
                    
                    // Calculate animated segment position along the route
                    final totalLength = _routePoints.length;
                    final segmentLength = (totalLength * 0.2).round().clamp(8, 30); // 20% of route length
                    final startIndex = ((animationValue * (totalLength + segmentLength)) % (totalLength + segmentLength)).round();
                    
                    // Create animated segment points
                    List<LatLng> animatedSegment = [];
                    if (startIndex < totalLength) {
                      final endIndex = (startIndex + segmentLength).clamp(0, totalLength);
                      animatedSegment = _routePoints.sublist(startIndex, endIndex);
                    }
                    
                    // Create pulsing effect for the animated segment
                    final pulseIntensity = 0.7 + (0.3 * (1 + math.sin(animationValue * 6 * math.pi)) / 2);
                    
                    return Stack(
                      children: [
                        // Base shadow layer - thin and semi-transparent for depth
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 8.0,
                              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              borderStrokeWidth: 0,
                            ),
                          ],
                        ),
                        // Main route polyline
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 6.0,
                              color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                              borderStrokeWidth: 0,
                            ),
                          ],
                        ),
                        // Animated moving segment - creates flowing effect
                        if (animatedSegment.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: animatedSegment,
                                strokeWidth: 8.0,
                                color: AppTheme.primaryBlueLight.withValues(alpha: pulseIntensity),
                                borderStrokeWidth: 2.0,
                                borderColor: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              // Leading edge marker - separate layer for better performance
              if (_routePoints.isNotEmpty)
                AnimatedBuilder(
                  animation: _polylineAnimationController,
                  builder: (context, child) {
                    final animationValue = _polylineAnimationController.value;
                    final totalLength = _routePoints.length;
                    final segmentLength = (totalLength * 0.2).round().clamp(8, 30);
                    final startIndex = ((animationValue * (totalLength + segmentLength)) % (totalLength + segmentLength)).round();
                    
                    if (startIndex >= totalLength || startIndex < 0) {
                      return const SizedBox.shrink();
                    }
                    
                    final leadingPoint = _routePoints[startIndex];
                    final pulseScale = 1.0 + (0.3 * (1 + math.sin(animationValue * 8 * math.pi)) / 2);
                    
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: leadingPoint,
                          width: 24 * pulseScale,
                          height: 24 * pulseScale,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  AppTheme.primaryBlueLight,
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryBlue,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
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
                  onTap: _navigateToSearch,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Search Route',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Display source and destination at top when set
          if (_sourceController.text.isNotEmpty || _destinationController.text.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: AppTheme.modernCardDecorationDark(
                  context,
                  color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentGreen,
                                AppTheme.accentGreen.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _sourceController.text.isNotEmpty
                                ? _sourceController.text
                                : 'Source',
                            style: AppTheme.bodyMediumDark(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: _sourceController.text.isNotEmpty
                                  ? null
                                  : (isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentRed,
                                AppTheme.accentRed.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _destinationController.text.isNotEmpty
                                ? _destinationController.text
                                : 'Destination',
                            style: AppTheme.bodyMediumDark(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: _destinationController.text.isNotEmpty
                                  ? null
                                  : (isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: AppTheme.gradientButtonDecoration(),
                          child: ElevatedButton(
                            onPressed: _sourceController.text.isNotEmpty && 
                                      _destinationController.text.isNotEmpty
                                ? () async {
                                    // Process search results and show bus list
                                    await _processSearchResults(
                                      _sourceController.text.trim(),
                                      _destinationController.text.trim(),
                                      null,
                                      null,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              minimumSize: const Size(0, 36),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search, size: 18, color: Colors.white),
                                const SizedBox(width: 4),
                                const Icon(Icons.directions_bus, size: 18, color: Colors.white),
                              ],
                            ),
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
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearRoute,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          // SOS Button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showSOSDialog,
              backgroundColor: Colors.red[700],
              elevation: 8,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
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
