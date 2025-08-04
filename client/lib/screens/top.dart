import 'package:flutter/material.dart';
import 'profile.dart';

class TopScreen extends StatelessWidget {
  static const routeName = '/top';

  const TopScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
                      Navigator.pushNamed(context, ProfileScreen.routeName);
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        'U', // First letter of user (capital)
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
          
          // Content area - this will be filled by the parent widget
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Center(
                child: Text(
                  'Content Area',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
