import 'package:flutter/material.dart';
import 'dart:async';
import 'profile.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';

class TopScreen extends StatefulWidget {
  static const routeName = '/top';

  const TopScreen({super.key});

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> with WidgetsBindingObserver {
  String _userInitial = 'U';
  double _walletBalance = 0.0;
  int _walletGems = 0;
  bool _isLoadingWallet = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadUserInfo();
    _loadWalletBalance();

    // Set up wallet update callback
    WalletService.setWalletUpdateCallback(_onWalletUpdate);

    // Set up periodic refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshWallet();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh wallet when screen comes into focus
    _refreshWallet();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh wallet when app comes back to foreground
      _refreshWallet();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WalletService.setWalletUpdateCallback(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onWalletUpdate(double balance, int gems) {
    if (mounted) {
      setState(() {
        _walletBalance = balance;
        _walletGems = gems;
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // You can add user info loading here if needed
      setState(() {
        _userInitial = 'U';
      });
    } catch (e) {
      setState(() {
        _userInitial = 'U';
      });
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      setState(() {
        _isLoadingWallet = true;
      });

      final result = await WalletService.getWalletBalance();

      if (mounted) {
        setState(() {
          if (result['success']) {
            _walletBalance = result['balance'];
            _walletGems = result['gems'];
          } else {
            _walletBalance = 0.0;
            _walletGems = 0;
          }
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletBalance = 0.0;
          _walletGems = 0;
          _isLoadingWallet = false;
        });
      }
    }
  }

  Future<void> _refreshWallet() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await WalletService.refreshWalletData();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet balance updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update wallet: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Public method to refresh wallet from other screens
  void refreshWalletFromExternal() {
    _refreshWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 60,
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
                  Text(
                    'SmartDhaka',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  Row(
                    children: [
                      Tooltip(
                        message: 'Tap to refresh wallet balance',
                        child: GestureDetector(
                          onTap: _refreshWallet,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 20,
                                  color: Colors.green[700],
                                ),
                                SizedBox(width: 8),
                                _isLoadingWallet
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.green[700]!),
                                        ),
                                      )
                                    : _isRefreshing
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.green[700]!),
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.refresh,
                                                size: 12,
                                                color: Colors.green[600],
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '৳${_walletBalance.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                              if (_walletGems > 0)
                                                Text(
                                                  '${_walletGems} 💎',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, ProfileScreen.routeName);
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            _userInitial,
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
