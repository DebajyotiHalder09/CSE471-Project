import 'package:flutter/material.dart';
import 'map.dart';
import 'bus.dart';
import 'rideshare.dart';
import 'driverDash.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../models/user.dart';
import '../models/individual_bus.dart';
import '../models/bus.dart' as bus_model;
import 'wallet_popup.dart';
import 'pay.dart';

class NavScreen extends StatefulWidget {
  static const routeName = '/nav';

  const NavScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  NavScreenState createState() => NavScreenState();
}

class NavScreenState extends State<NavScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  bool _isLoading = true;
  double _walletBalance = 0.0;
  int _gems = 0;
  bool _isRefreshingWallet = false;

  String? _rideSource;
  String? _rideDestination;

  // Boarding state
  bool _isBoarding = false;
  IndividualBus? _boardedBus;
  bus_model.Bus? _boardedBusInfo;
  String? _boardingSource;
  String? _boardingDestination;
  double? _boardingDistance;
  double? _boardingFare;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();

    // Register wallet update callback
    WalletService.setWalletUpdateCallback((balance, gems) {
      setState(() {
        _walletBalance = balance;
        _gems = gems;
      });
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });

      if (user != null) {
        await _loadWalletData();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWalletData() async {
    try {
      final walletResponse = await WalletService.getWalletBalance();
      if (walletResponse['success']) {
        setState(() {
          _walletBalance = walletResponse['balance'] ?? 0.0;
          _gems = walletResponse['gems'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
    }
  }

  Future<void> _refreshWalletData() async {
    setState(() {
      _isRefreshingWallet = true;
    });

    try {
      final walletResponse = await WalletService.refreshWalletData();
      if (walletResponse['success']) {
        setState(() {
          _walletBalance = walletResponse['balance'] ?? 0.0;
          _gems = walletResponse['gems'] ?? 0;
        });
      }
    } catch (e) {
      print('Error refreshing wallet data: $e');
    } finally {
      setState(() {
        _isRefreshingWallet = false;
      });
    }
  }

  void _showWalletPopup() {
    showDialog(
      context: context,
      builder: (context) => WalletPopup(
        currentBalance: _walletBalance,
        currentGems: _gems,
        onWalletUpdated: () async {
          await _refreshWalletData();
        },
      ),
    );
  }

  void _handleEndTrip() {
    if (_boardedBus != null && _boardedBusInfo != null && 
        _boardingSource != null && _boardingDestination != null &&
        _boardingDistance != null && _boardingFare != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PayScreen(
            bus: _boardedBus!,
            busInfo: _boardedBusInfo!,
            source: _boardingSource!,
            destination: _boardingDestination!,
            distance: _boardingDistance!,
            fare: _boardingFare!,
            isBoarding: true, // Indicate that user is already boarded
          ),
        ),
      ).then((_) {
        // Clear boarding state after payment is complete
        setState(() {
          _isBoarding = false;
          _boardedBus = null;
          _boardedBusInfo = null;
          _boardingSource = null;
          _boardingDestination = null;
          _boardingDistance = null;
          _boardingFare = null;
        });
      });
    }
  }

  @override
  void dispose() {
    // Clear wallet update callback
    WalletService.setWalletUpdateCallback(null);
    super.dispose();
  }

  Widget _getScreenAtIndex(int index) {
    switch (index) {
      case 0:
        return MapScreen(
          onOpenRideshare: (source, destination) {
            setState(() {
              _rideSource = source;
              _rideDestination = destination;
              _currentIndex = 2;
            });
          },
          onBoarded: (individualBus, busInfo, source, destination, distance, fare) {
            setState(() {
              _isBoarding = true;
              _boardedBus = individualBus;
              _boardedBusInfo = busInfo;
              _boardingSource = source;
              _boardingDestination = destination;
              _boardingDistance = distance;
              _boardingFare = fare;
            });
          },
        );
      case 1:
        return BusScreen();
      case 2:
        if (_currentUser?.role == 'driver') {
          return DriverDashScreen();
        } else {
          return RideshareScreen(
            source: _rideSource,
            destination: _rideDestination,
          );
        }
      default:
        return MapScreen(
          onOpenRideshare: (source, destination) {
            setState(() {
              _rideSource = source;
              _rideDestination = destination;
              _currentIndex = 2;
            });
          },
          onBoarded: (individualBus, busInfo, source, destination, distance, fare) {
            setState(() {
              _isBoarding = true;
              _boardedBus = individualBus;
              _boardedBusInfo = busInfo;
              _boardingSource = source;
              _boardingDestination = destination;
              _boardingDistance = distance;
              _boardingFare = fare;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              height: 60, // Smaller height than nav.dart
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // SmartDhaka text on the left
                    Text(
                      'SmartDhaka',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),

                    // Wallet info and profile picture on the right
                    Row(
                      children: [
                        // Gem icon with count
                        GestureDetector(
                          onTap: () async {
                            await _refreshWalletData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Wallet refreshed!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple[50]!,
                                  Colors.purple[100]!
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.purple[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                _isRefreshingWallet
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.purple[700]!),
                                        ),
                                      )
                                    : Icon(
                                        Icons.diamond,
                                        size: 20,
                                        color: Colors.purple[700],
                                      ),
                                if (_gems > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$_gems',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Wallet balance display
                        GestureDetector(
                          onTap: _showWalletPopup,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[50]!, Colors.green[100]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.green[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 18,
                                  color: Colors.green[700],
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '৳${_walletBalance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Circular avatar
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue[100],
                            child: _isLoading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue[700]!),
                                    ),
                                  )
                                : Text(
                                    _currentUser?.firstNameInitial ?? 'U',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Main content area
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _refreshWalletData();
                },
                child: _getScreenAtIndex(_currentIndex),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isBoarding
          ? Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: _handleEndTrip,
                    icon: Icon(Icons.stop_circle, size: 24),
                    label: Text(
                      'End Trip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            )
          : Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.map, size: 24),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus, size: 24),
              label: 'Bus',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                  _currentUser?.role == 'driver'
                      ? Icons.directions_car
                      : Icons.local_taxi,
                  size: 24),
              label: _currentUser?.role == 'driver' ? 'Driver' : 'Rideshare',
            ),
          ],
        ),
      ),
    );
  }
}
