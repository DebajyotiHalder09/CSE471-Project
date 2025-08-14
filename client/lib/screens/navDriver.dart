import 'package:flutter/material.dart';
import 'map.dart';
import 'bus.dart';
import 'driverDash.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class NavDriverScreen extends StatefulWidget {
  static const routeName = '/navDriver';

  const NavDriverScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  NavDriverScreenState createState() => NavDriverScreenState();
}

class NavDriverScreenState extends State<NavDriverScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();
  }

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

  Widget _getScreenAtIndex(int index) {
    switch (index) {
      case 0:
        return MapScreen(
          onOpenRideshare: (source, destination) {
            // For drivers, this could open a different screen or do nothing
            // For now, we'll just show a message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Driver mode: Use Driver Dashboard to accept rides'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        );
      case 1:
        return BusScreen();
      case 2:
        return DriverDashScreen();
      default:
        return MapScreen(
          onOpenRideshare: (source, destination) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Driver mode: Use Driver Dashboard to accept rides'),
                backgroundColor: Colors.blue,
              ),
            );
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
              height: 60,
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

                    // Driver indicator and avatar on the right
                    Row(
                      children: [
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
                                    _currentUser?.firstNameInitial ?? 'D',
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
              child: _getScreenAtIndex(_currentIndex),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
          selectedItemColor: Colors.green[700],
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
              icon: Icon(Icons.directions_car, size: 24),
              label: 'Driver',
            ),
          ],
        ),
      ),
    );
  }
}
