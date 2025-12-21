import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'map.dart';
import 'bus.dart';
import 'rideshare.dart';
import 'driverDash.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../models/individual_bus.dart';
import '../models/bus.dart' as bus_model;
import 'wallet_popup.dart';
import 'pay.dart';
import 'notifications.dart';
import 'dart:async';

class NavScreen extends StatefulWidget {
  static const routeName = '/nav';

  const NavScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  NavScreenState createState() => NavScreenState();
}

class NavScreenState extends State<NavScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  User? _currentUser;
  bool _isLoading = true;
  double _walletBalance = 0.0;
  int _gems = 0;
  bool _isRefreshingWallet = false;
  int _unreadNotificationCount = 0;
  late AnimationController _bannerAnimationController;
  late Animation<Offset> _bannerSlideAnimation;
  Timer? _bannerDismissTimer;

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
    
    // Load notification count
    _loadNotificationCount();
    
    // Poll for new notifications every 30 seconds
    _startNotificationPolling();
    
    // Initialize banner animation
    _bannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadNotificationCount() async {
    try {
      final result = await NotificationService.getUnreadCount();
      if (result['success'] && mounted) {
        final previousCount = _unreadNotificationCount;
        final newCount = result['count'] ?? 0;
        
        setState(() {
          _unreadNotificationCount = newCount;
        });
        
        // If count increased, show banner with animation
        if (newCount > previousCount && newCount > 0) {
          _showNotificationBanner();
        } else if (newCount == 0) {
          _hideNotificationBanner();
        } else if (newCount > 0 && previousCount == 0) {
          // Initial load with notifications - show banner
          _showNotificationBanner();
        }
      }
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  void _showNotificationBanner() {
    _bannerAnimationController.forward();
    // Auto-dismiss after 5 seconds
    _bannerDismissTimer?.cancel();
    _bannerDismissTimer = Timer(const Duration(seconds: 5), () {
      _hideNotificationBanner();
    });
  }

  void _hideNotificationBanner() {
    _bannerAnimationController.reverse();
    _bannerDismissTimer?.cancel();
  }

  void _startNotificationPolling() {
    // Poll every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadNotificationCount();
        _startNotificationPolling();
      }
    });
  }

  Future<void> _triggerSOS() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to use SOS'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Show SOS options dialog
    final option = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.emergency_rounded, color: AppTheme.accentRed, size: 28),
            const SizedBox(width: 12),
            const Text('SOS Emergency'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose emergency service:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Ambulance
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'ambulance'),
              icon: const Icon(Icons.local_hospital_rounded),
              label: const Text('Ambulance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            // Police
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'police'),
              icon: const Icon(Icons.local_police_rounded),
              label: const Text('Police'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            // Fire
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'fire'),
              icon: const Icon(Icons.fire_extinguisher_rounded),
              label: const Text('Fire'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            // Trigger (General SOS)
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'trigger'),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Trigger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );

    if (option == null) return;

    // For trigger, skip confirmation and directly send
    if (option == 'trigger') {
      // Directly trigger without confirmation
      await _sendSOSNotification('trigger', 'Emergency', AppTheme.accentRed);
      return;
    }

    // Get service name and color based on option
    String serviceName;
    Color serviceColor;
    String callingText;
    
    switch (option) {
      case 'ambulance':
        serviceName = 'Ambulance';
        serviceColor = Colors.red[700]!;
        callingText = 'Calling ambulance station...';
        break;
      case 'police':
        serviceName = 'Police';
        serviceColor = Colors.blue[700]!;
        callingText = 'Calling police station...';
        break;
      case 'fire':
        serviceName = 'Fire';
        serviceColor = Colors.orange[700]!;
        callingText = 'Calling fire station...';
        break;
      default:
        serviceName = 'Emergency';
        serviceColor = AppTheme.accentRed;
        callingText = '';
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: serviceColor, size: 28),
            const SizedBox(width: 12),
            const Text('Confirm'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              callingText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: serviceColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will send a $serviceName notification to all users with your username and location (Gulistan).',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: serviceColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send notification
    await _sendSOSNotification(option, serviceName, serviceColor);
  }

  Future<void> _sendSOSNotification(String option, String serviceName, Color serviceColor) async {

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fixed location: Gulistan
      final result = await NotificationService.createSOSNotification(
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        source: 'Gulistan',
        latitude: null,
        longitude: null,
        serviceType: option,
        serviceName: serviceName,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$serviceName request sent to ${result['count']} users',
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to send notification'),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
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
    // Dispose banner animation
    _bannerAnimationController.dispose();
    _bannerDismissTimer?.cancel();
    super.dispose();
  }

  Widget _buildNotificationBanner() {
    if (_unreadNotificationCount == 0) return const SizedBox.shrink();
    
    return SlideTransition(
      position: _bannerSlideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlueLight,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  _hideNotificationBanner();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  _loadNotificationCount();
                },
                child: Text(
                  _unreadNotificationCount == 1
                      ? 'You have 1 new notification'
                      : 'You have $_unreadNotificationCount new notifications',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _hideNotificationBanner,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
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
        child: Stack(
          children: [
            Column(
              children: [
                // Top Bar - Modern Compact Design
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App Logo - Smaller
                        Image.asset(
                          'assets/main.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),

                        // Right side: Gems, Wallet, Profile
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Gem icon - No box, just icon with badge
                            GestureDetector(
                              onTap: () async {
                            await _refreshWalletData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Wallet refreshed!'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: AppTheme.accentGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _isRefreshingWallet
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                  AppTheme.accentPurple),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.diamond,
                                            size: 24,
                                            color: AppTheme.accentPurple,
                                          ),
                                    if (_gems > 0)
                                      Positioned(
                                        right: -6,
                                        top: -6,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentRed,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.accentRed.withOpacity(0.4),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _gems > 99 ? '99+' : '$_gems',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              height: 1.0,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Wallet balance - Bigger and more visible
                            GestureDetector(
                              onTap: _showWalletPopup,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentGreen.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '৳${_walletBalance.toStringAsFixed(0)}',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Notification bell icon
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NotificationsScreen(),
                                  ),
                                );
                                _loadNotificationCount();
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? AppTheme.darkSurfaceElevated 
                                      : AppTheme.backgroundLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark 
                                        ? AppTheme.darkBorder 
                                        : AppTheme.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.notifications_outlined,
                                      size: 22,
                                      color: isDark 
                                          ? AppTheme.darkTextPrimary 
                                          : AppTheme.textPrimary,
                                    ),
                                    if (_unreadNotificationCount > 0)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.accentRed,
                                                AppTheme.accentRed.withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark 
                                                  ? AppTheme.darkSurface 
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.accentRed.withOpacity(0.4),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _unreadNotificationCount > 99 
                                                ? '99+' 
                                                : '$_unreadNotificationCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              height: 1.0,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Profile avatar - Smaller
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/profile');
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(1.5),
                                child: Builder(
                                  builder: (context) {
                                    final isDark = Theme.of(context).brightness == Brightness.dark;
                                    return CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                    AppTheme.primaryBlue),
                                              ),
                                            )
                                          : Text(
                                              _currentUser?.firstNameInitial ?? 'U',
                                              style: AppTheme.bodyMedium.copyWith(
                                                color: AppTheme.primaryBlue,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                    );
                                  },
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
        // Notification Banner - Positioned underneath top nav bar
        Positioned(
          top: 56, // Height of top nav bar
          left: 0,
          right: 0,
          child: _buildNotificationBanner(),
        ),
        // SOS Floating Action Button
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _triggerSOS,
            backgroundColor: AppTheme.accentRed,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('SOS'),
            elevation: 8,
            heroTag: 'sos_button',
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
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
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
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppTheme.primaryBlue,
                unselectedItemColor: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                selectedLabelStyle: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                selectedIconTheme: const IconThemeData(
                  size: 26,
                ),
                unselectedIconTheme: const IconThemeData(
                  size: 24,
                ),
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _currentIndex == 0
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: const Icon(Icons.map_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.map),
                ),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _currentIndex == 1
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: const Icon(Icons.directions_bus_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.directions_bus),
                ),
                label: 'Bus',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _currentIndex == 2
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    _currentUser?.role == 'driver'
                        ? Icons.directions_car_outlined
                        : Icons.local_taxi_outlined,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                  ),
                  child: Icon(
                    _currentUser?.role == 'driver'
                        ? Icons.directions_car
                        : Icons.local_taxi,
                  ),
                ),
                label: _currentUser?.role == 'driver' ? 'Driver' : 'Rideshare',
              ),
            ],
              ),
            );
          },
        ),
      ),
    );
  }
}
