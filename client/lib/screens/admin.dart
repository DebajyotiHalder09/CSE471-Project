import 'package:flutter/material.dart';
import '../services/bus_service.dart';
import '../services/auth_service.dart';
import '../services/verify_service.dart';
import '../models/bus.dart';
import '../utils/app_theme.dart';
import '../utils/error_widgets.dart';
import '../utils/loading_widgets.dart';
import 'review.dart';

class AdminScreen extends StatefulWidget {
  static const routeName = '/admin';

  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  List<Bus> allBuses = [];
  bool isLoading = false;
  String? errorMessage;
  String? currentUserName;
  
  // Verify tab state
  List<Map<String, dynamic>> verifications = [];
  bool isLoadingVerifications = false;
  String? verifyErrorMessage;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadAllBuses();
    _loadVerifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        currentUserName = user.name;
      });
    }
  }

  Future<void> _loadAllBuses() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await BusService.getAllBuses();

      if (response['success']) {
        setState(() {
          allBuses = (response['data'] as List)
              .map((json) => Bus.fromJson(json))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load buses';
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

  Future<void> _refreshBuses() async {
    await _loadAllBuses();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bus list refreshed'),
        duration: Duration(seconds: 1),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _loadVerifications() async {
    setState(() {
      isLoadingVerifications = true;
      verifyErrorMessage = null;
    });

    try {
      final response = await VerifyService.getAllVerifications();
      if (response['success']) {
        setState(() {
          verifications = List<Map<String, dynamic>>.from(response['data'] ?? []);
          isLoadingVerifications = false;
        });
      } else {
        setState(() {
          verifyErrorMessage = response['message'] ?? 'Failed to load verifications';
          isLoadingVerifications = false;
        });
      }
    } catch (e) {
      setState(() {
        verifyErrorMessage = e.toString();
        isLoadingVerifications = false;
      });
    }
  }

  Future<void> _approveVerification(String verificationId) async {
    try {
      final response = await VerifyService.approveVerification(verificationId);
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification approved successfully'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadVerifications();
      } else {
        ErrorSnackbar.show(
          context,
          response['message'] ?? 'Failed to approve verification',
        );
      }
    } catch (e) {
      ErrorSnackbar.show(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _rejectVerification(String verificationId) async {
    try {
      final response = await VerifyService.rejectVerification(verificationId);
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification rejected'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
        _loadVerifications();
      } else {
        ErrorSnackbar.show(
          context,
          response['message'] ?? 'Failed to reject verification',
        );
      }
    } catch (e) {
      ErrorSnackbar.show(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _blockBus(String busId) async {
    // TODO: Implement bus blocking functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bus blocking functionality will be implemented'),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  void _showBusOptionsModal(Bus bus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.busName,
                          style: AppTheme.heading4Dark(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bus.routeNumber != null)
                          Text(
                            'Route: ${bus.routeNumber}',
                            style: AppTheme.bodySmallDark(context),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Options
              _buildModalOption(
                icon: Icons.reviews_rounded,
                title: 'View Reviews',
                subtitle: 'See all reviews for this bus',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewScreen(bus: bus),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildModalOption(
                icon: Icons.block_rounded,
                title: 'Block Bus',
                subtitle: 'Block this bus from the system',
                color: AppTheme.accentRed,
                onTap: () {
                  Navigator.of(context).pop();
                  _showBlockConfirmation(bus);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLargeDark(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmallDark(context),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockConfirmation(Bus bus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Block Bus',
          style: AppTheme.heading4Dark(context).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to block "${bus.busName}"? This action can be reversed later.',
          style: AppTheme.bodyMediumDark(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.labelMedium.copyWith(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentRed, AppTheme.accentRed.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _blockBus(bus.id);
              },
              child: Text(
                'Block',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.clearStoredData();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Admin Dashboard',
              style: AppTheme.heading3Dark(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_tabController.index == 0) {
                _refreshBuses();
              } else {
                _loadVerifications();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus_rounded), text: 'Buses'),
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Verify'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${currentUserName ?? 'Admin'}!',
                  style: AppTheme.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tabController.index == 0
                      ? 'Total Buses: ${allBuses.length}'
                      : 'Pending Verifications: ${verifications.where((v) => v['status'] == 'hold').length}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBusesTab(),
                _buildVerifyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusesTab() {
    return isLoading
        ? Center(
            child: LoadingWidget(
              message: 'Loading buses...',
            ),
          )
        : errorMessage != null
            ? ErrorDisplayWidget(
                message: errorMessage!,
                icon: Icons.error_outline_rounded,
                onRetry: _loadAllBuses,
              )
            : allBuses.isEmpty
                ? EmptyStateWidget(
                    title: 'No buses found',
                    message: 'No buses are registered in the system',
                    icon: Icons.directions_bus_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: _loadAllBuses,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: allBuses.length,
                      itemBuilder: (context, index) {
                        return _buildBusCard(allBuses[index]);
                      },
                    ),
                  );
  }

  Widget _buildVerifyTab() {
    return isLoadingVerifications
        ? Center(
            child: LoadingWidget(
              message: 'Loading verifications...',
            ),
          )
        : verifyErrorMessage != null
            ? ErrorDisplayWidget(
                message: verifyErrorMessage!,
                icon: Icons.error_outline_rounded,
                onRetry: _loadVerifications,
              )
            : verifications.isEmpty
                ? EmptyStateWidget(
                    title: 'No verification requests',
                    message: 'All verification requests have been processed',
                    icon: Icons.verified_user_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: _loadVerifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: verifications.length,
                      itemBuilder: (context, index) {
                        return _buildVerificationCard(verifications[index]);
                      },
                    ),
                  );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = verification['status'] ?? 'hold';
    final statusColor = status == 'approved'
        ? AppTheme.accentGreen
        : status == 'rejected'
            ? AppTheme.accentRed
            : AppTheme.accentOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.modernCardDecorationDark(
        context,
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor,
                  statusColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              status == 'approved'
                  ? Icons.check_circle_rounded
                  : status == 'rejected'
                      ? Icons.cancel_rounded
                      : Icons.pending_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            verification['userName'] ?? 'Unknown User',
            style: AppTheme.heading4Dark(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Email: ${verification['userEmail'] ?? 'N/A'}',
                style: AppTheme.bodySmallDark(context),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AppTheme.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Institution Name', verification['institutionName'] ?? 'N/A'),
                  _buildDetailRow('Institution ID', verification['institutionId'] ?? 'N/A'),
                  _buildDetailRow('Gmail', verification['gmail'] ?? 'N/A'),
                  _buildDetailRow('Submitted', verification['createdAt'] != null
                      ? DateTime.parse(verification['createdAt']).toString().split('.')[0]
                      : 'N/A'),
                  if (verification['imageUrl'] != null && verification['imageUrl'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Student ID Image:',
                      style: AppTheme.heading4Dark(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.8,
                                maxWidth: MediaQuery.of(context).size.width * 0.9,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    title: Text(
                                      'Student ID Image',
                                      style: AppTheme.heading4Dark(context),
                                    ),
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Image.network(
                                        verification['imageUrl'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 48),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Failed to load image',
                                                  style: AppTheme.bodyMediumDark(context),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Image.network(
                                verification['imageUrl'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline_rounded, color: AppTheme.accentRed),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: AppTheme.bodySmallDark(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (status == 'hold') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentGreen,
                                  AppTheme.accentGreen.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _approveVerification(verification['_id']),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Approve',
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentRed,
                                  AppTheme.accentRed.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _rejectVerification(verification['_id']),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Reject',
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
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: AppTheme.bodyMediumDark(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTheme.bodyMediumDark(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCard(Bus bus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busTypeColor = _getBusTypeColor(bus.busType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.modernCardDecorationDark(
        context,
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBusOptionsModal(bus),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        busTypeColor,
                        busTypeColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.busName,
                        style: AppTheme.heading4Dark(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (bus.routeNumber != null)
                        Text(
                          'Route: ${bus.routeNumber}',
                          style: AppTheme.bodySmallDark(context),
                        ),
                      if (bus.operator != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Operator: ${bus.operator}',
                          style: AppTheme.bodySmallDark(context),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: busTypeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: busTypeColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              bus.busType.toUpperCase(),
                              style: AppTheme.labelSmall.copyWith(
                                color: busTypeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${bus.stops.length} stops',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBusTypeColor(String busType) {
    switch (busType.toLowerCase()) {
      case 'women':
        return Colors.pink;
      case 'general':
        return AppTheme.primaryBlue;
      default:
        return AppTheme.textSecondary;
    }
  }
}
