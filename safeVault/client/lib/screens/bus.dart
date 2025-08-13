import 'package:flutter/material.dart';
import '../services/bus_service.dart';
import '../services/fav_bus_service.dart';
import '../services/auth_service.dart';
import '../models/bus.dart';
import 'review.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  _BusScreenState createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  String selectedSearchType = 'bus'; // 'bus' or 'route'
  TextEditingController busNameController = TextEditingController();
  TextEditingController startLocationController = TextEditingController();
  TextEditingController endLocationController = TextEditingController();

  List<Bus> searchResults = [];
  List<Bus> allBuses = [];
  bool isLoading = false;
  bool isLoadingAll = false;
  String? errorMessage;
  String? currentUserId;
  Map<String, bool> favoriteStatus = {};

  @override
  void initState() {
    super.initState();
    _loadAllBuses();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    busNameController.dispose();
    startLocationController.dispose();
    endLocationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        currentUserId = user.id;
      });
      _loadFavoriteStatuses();
    }
  }

  Future<void> _loadFavoriteStatuses() async {
    if (currentUserId == null) return;

    for (final bus in allBuses) {
      try {
        final response = await FavBusService.checkIfFavorited(
          userId: currentUserId!,
          busId: bus.id,
        );
        if (response['success']) {
          setState(() {
            favoriteStatus[bus.id] = response['isFavorited'];
          });
        }
      } catch (e) {
        setState(() {
          favoriteStatus[bus.id] = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Bus bus) async {
    if (currentUserId == null) return;

    try {
      if (favoriteStatus[bus.id] == true) {
        await FavBusService.removeFromFavorites(
          userId: currentUserId!,
          busId: bus.id,
        );
        setState(() {
          favoriteStatus[bus.id] = false;
        });
      } else {
        await FavBusService.addToFavorites(
          userId: currentUserId!,
          busId: bus.id,
          busName: bus.busName,
          routeNumber: bus.routeNumber,
          operator: bus.operator,
        );
        setState(() {
          favoriteStatus[bus.id] = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAllBuses() async {
    setState(() {
      isLoadingAll = true;
      errorMessage = null;
    });

    try {
      final response = await BusService.getAllBuses();

      if (response['success']) {
        setState(() {
          allBuses = (response['data'] as List)
              .map((json) => Bus.fromJson(json))
              .toList();
          isLoadingAll = false;
        });
        _loadFavoriteStatuses();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load buses';
          isLoadingAll = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingAll = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      searchResults.clear();
      errorMessage = null;
      busNameController.clear();
      startLocationController.clear();
      endLocationController.clear();
    });
    _loadFavoriteStatuses();
  }

  Future<void> _searchBusByName() async {
    if (busNameController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter a bus name';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response =
          await BusService.searchBusByName(busNameController.text.trim());

      if (response['success']) {
        setState(() {
          searchResults = (response['data'] as List)
              .map((json) => Bus.fromJson(json))
              .toList();
          isLoading = false;
        });
        _loadFavoriteStatusesForSearchResults();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'No buses found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _searchBusByRoute() async {
    if (startLocationController.text.trim().isEmpty ||
        endLocationController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter both start and end locations';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await BusService.searchBusByRoute(
        startLocationController.text.trim(),
        endLocationController.text.trim(),
      );

      if (response['success']) {
        setState(() {
          searchResults = (response['data'] as List)
              .map((json) => Bus.fromJson(json))
              .toList();
          isLoading = false;
        });
        _loadFavoriteStatusesForSearchResults();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'No buses found for this route';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadFavoriteStatusesForSearchResults() async {
    if (currentUserId == null) return;

    for (final bus in searchResults) {
      try {
        final response = await FavBusService.checkIfFavorited(
          userId: currentUserId!,
          busId: bus.id,
        );
        if (response['success']) {
          setState(() {
            favoriteStatus[bus.id] = response['isFavorited'];
          });
        }
      } catch (e) {
        setState(() {
          favoriteStatus[bus.id] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter and Search Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Search & Filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedSearchType =
                                  selectedSearchType == 'bus' ? 'route' : 'bus';
                              _clearSearch();
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selectedSearchType == 'bus'
                                    ? Icons.route
                                    : Icons.directions_bus,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 6),
                              Text(
                                selectedSearchType == 'bus' ? 'Route' : 'Bus',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (selectedSearchType == 'bus') ...[
                    TextField(
                      controller: busNameController,
                      decoration: InputDecoration(
                        hintText: 'Enter bus name...',
                        prefixIcon: Icon(Icons.directions_bus),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _searchBusByName(),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _searchBusByName,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Search Bus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startLocationController,
                            decoration: InputDecoration(
                              hintText: 'Start location...',
                              prefixIcon: Icon(Icons.location_on, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: endLocationController,
                            decoration: InputDecoration(
                              hintText: 'End location...',
                              prefixIcon:
                                  Icon(Icons.location_on_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _searchBusByRoute(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _searchBusByRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Search Route',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 16),

            // Error Message
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Results Section
            Expanded(
              child: searchResults.isNotEmpty
                  ? ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final bus = searchResults[index];
                        return BusResultCard(
                          bus: bus,
                          isFavorited: favoriteStatus[bus.id] ?? false,
                          onFavoriteToggle: () => _toggleFavorite(bus),
                        );
                      },
                    )
                  : allBuses.isNotEmpty
                      ? ListView.builder(
                          itemCount: allBuses.length,
                          itemBuilder: (context, index) {
                            final bus = allBuses[index];
                            return BusResultCard(
                              bus: bus,
                              isFavorited: favoriteStatus[bus.id] ?? false,
                              onFavoriteToggle: () => _toggleFavorite(bus),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No buses available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No buses found in the system',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusResultCard extends StatefulWidget {
  final Bus bus;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;

  const BusResultCard({
    super.key,
    required this.bus,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  _BusResultCardState createState() => _BusResultCardState();
}

class _BusResultCardState extends State<BusResultCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(
                Icons.directions_bus,
                color: Colors.blue[700],
              ),
            ),
            title: Text(
              widget.bus.busName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.bus.routeNumber != null)
                  Text(
                    'Route: ${widget.bus.routeNumber}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                if (widget.bus.operator != null)
                  Text(
                    'Operator: ${widget.bus.operator}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                Text(
                  '${widget.bus.stops.length} stops',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.message,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewScreen(bus: widget.bus),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    widget.isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: widget.onFavoriteToggle,
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (isExpanded)
            Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(),
                  Text(
                    'Stops:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children:
                          widget.bus.stopNames.asMap().entries.map((entry) {
                        int index = entry.key;
                        String stop = entry.value;
                        bool isLast = index == widget.bus.stops.length - 1;
                        return Container(
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 0.5,
                                    ),
                                  ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? Colors.green
                                        : index == widget.bus.stops.length - 1
                                            ? Colors.red
                                            : Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      index == 0
                                          ? Icons.trip_origin
                                          : index == widget.bus.stops.length - 1
                                              ? Icons.location_on
                                              : Icons.circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Text(
                                        index == 0
                                            ? 'Starting Point'
                                            : index ==
                                                    widget.bus.stops.length - 1
                                                ? 'Final Destination'
                                                : 'Stop ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
