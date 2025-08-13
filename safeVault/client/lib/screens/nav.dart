import 'package:flutter/material.dart';
import 'map.dart';
import 'bus.dart';
import 'rideshare.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class NavScreen extends StatefulWidget {
  static const routeName = '/nav';

  const NavScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  _NavScreenState createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  bool _isLoading = true;

  String? _rideSource;
  String? _rideDestination;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _currentIndex = widget.initialIndex;
  }

  List<Widget> get _screens => [
        MapScreen(
          onOpenRideshare: (source, destination) {
            setState(() {
              _rideSource = source;
              _rideDestination = destination;
              _currentIndex = 2;
            });
          },
        ),
        BusScreen(),
        RideshareScreen(
          source: _rideSource,
          destination: _rideDestination,
        ),
      ];

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
                    color: Colors.black.withOpacity(0.1),
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

                    // Circular avatar on the right
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
              ),
            ),

            // Main content area
            Expanded(
              child: _screens[_currentIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              icon: Icon(Icons.local_taxi, size: 24),
              label: 'Rideshare',
            ),
          ],
        ),
      ),
    );
  }
}
