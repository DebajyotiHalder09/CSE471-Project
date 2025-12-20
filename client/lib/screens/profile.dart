import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
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
  String? _friendCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      final friendCode = await AuthService.getCurrentUserFriendCode();
      setState(() {
        _currentUser = user;
        _friendCode = friendCode;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTheme.heading3Dark(context),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: AppTheme.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                              child: Text(
                                _currentUser?.firstNameInitial ?? 'U',
                                style: AppTheme.heading1Dark(context).copyWith(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _currentUser?.name ?? 'User Name',
                            style: AppTheme.heading2Dark(context),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Friend Code: ${_friendCode ?? 'Loading...'}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildProfileItem(Icons.person, 'Personal Information',
                        onTap: () {
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
                    if (_currentUser?.role != 'driver' && _currentUser?.role != 'admin')
                      _buildProfileItem(Icons.verified_user, 'Verify', onTap: () {
                        Navigator.pushNamed(context, '/verify');
                      }),
                    _buildProfileItem(Icons.history, 'Trip History', onTap: () {
                      Navigator.pushNamed(context, '/trip-history');
                    }),
                    _buildProfileItem(Icons.people, 'Friends', onTap: () {
                      Navigator.pushNamed(context, '/friends');
                    }),
                    _buildProfileItem(Icons.local_offer, 'Offers', onTap: () {
                      Navigator.pushNamed(context, '/offers');
                    }),
                    _buildProfileItem(Icons.qr_code, 'QR Code', onTap: () {
                      Navigator.pushNamed(context, '/qr');
                    }),
                    _buildProfileItem(Icons.settings, 'Settings', onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    }),
                    _buildProfileItem(Icons.help, 'Help & Support'),
                    _buildProfileItem(Icons.logout, 'Logout', onTap: _logout, isLogout: true),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {VoidCallback? onTap, bool isLogout = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.modernCardDecorationDark(
        context,
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLogout 
                        ? AppTheme.accentRed.withOpacity(0.1)
                        : AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? AppTheme.accentRed : AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyLargeDark(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isLogout 
                          ? AppTheme.accentRed 
                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isLogout 
                      ? AppTheme.accentRed 
                      : (isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
