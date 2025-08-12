import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'pinfo.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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

  Future<void> _logout() async {
    try {
      await AuthService().logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              _currentUser?.firstNameInitial ?? 'U',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _currentUser?.name ?? 'User Name',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildProfileItem(Icons.person, 'Personal Information', onTap: () {
                      print('Navigating to personal info page');
                      try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonalInfoScreen(),
                          ),
                        );
                      } catch (e) {
                        print('Navigation error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Navigation failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }),
                    _buildProfileItem(Icons.history, 'Trip History'),
                    _buildProfileItem(Icons.favorite, 'Favorites'),
                    _buildProfileItem(Icons.settings, 'Settings'),
                    _buildProfileItem(Icons.help, 'Help & Support'),
                    _buildProfileItem(Icons.logout, 'Logout', onTap: _logout),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {VoidCallback? onTap}) {
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
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap ?? () {
          // Handle navigation for each item
        },
      ),
    );
  }
}
