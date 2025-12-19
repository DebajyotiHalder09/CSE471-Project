import 'package:flutter/material.dart';
import '../services/bus_service.dart';
import '../services/auth_service.dart';
import '../services/verify_service.dart';
import '../models/bus.dart';

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
            backgroundColor: Colors.green,
          ),
        );
        _loadVerifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to approve verification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectVerification(String verificationId) async {
    try {
      final response = await VerifyService.rejectVerification(verificationId);
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadVerifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to reject verification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.clearStoredData();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.directions_bus), text: 'Buses'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verify'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${currentUserName ?? 'Admin'}!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _tabController.index == 0
                      ? 'Total Buses: ${allBuses.length}'
                      : 'Pending Verifications: ${verifications.where((v) => v['status'] == 'hold').length}',
                  style: TextStyle(
                    fontSize: 16,
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
        ? Center(child: CircularProgressIndicator())
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadAllBuses, child: Text('Retry')),
                  ],
                ),
              )
            : allBuses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No buses found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAllBuses,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: allBuses.length,
                      itemBuilder: (context, index) {
                        return _buildBusCard(allBuses[index]);
                      },
                    ),
                  );
  }

  Widget _buildVerifyTab() {
    return isLoadingVerifications
        ? Center(child: CircularProgressIndicator())
        : verifyErrorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(
                      verifyErrorMessage!,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadVerifications, child: Text('Retry')),
                  ],
                ),
              )
            : verifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No verification requests', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVerifications,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: verifications.length,
                      itemBuilder: (context, index) {
                        return _buildVerificationCard(verifications[index]);
                      },
                    ),
                  );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final status = verification['status'] ?? 'hold';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;

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
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            status == 'approved'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.pending,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          verification['userName'] ?? 'Unknown User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Email: ${verification['userEmail'] ?? 'N/A'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
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
                  SizedBox(height: 16),
                  Text(
                    'Student ID Image:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Show full screen image
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.8,
                              maxWidth: MediaQuery.of(context).size.width * 0.9,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppBar(
                                  title: Text('Student ID Image'),
                                  actions: [
                                    IconButton(
                                      icon: Icon(Icons.close),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Image.network(
                                    verification['imageUrl'],
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error, color: Colors.red, size: 48),
                                            SizedBox(height: 16),
                                            Text('Failed to load image'),
                                          ],
                                        ),
                                      );
                                    },
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.network(
                              verification['imageUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        SizedBox(height: 8),
                                        Text('Failed to load image'),
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
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.zoom_in,
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
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveVerification(verification['_id']),
                          icon: Icon(Icons.check),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectVerification(verification['_id']),
                          icon: Icon(Icons.close),
                          label: Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCard(Bus bus) {
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
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getBusTypeColor(bus.busType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.directions_bus,
            color: _getBusTypeColor(bus.busType),
            size: 24,
          ),
        ),
        title: Text(
          bus.busName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (bus.routeNumber != null)
              Text(
                'Route: ${bus.routeNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            if (bus.operator != null)
              Text(
                'Operator: ${bus.operator}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getBusTypeColor(bus.busType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            bus.busType.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getBusTypeColor(bus.busType),
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fare Information
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.attach_money,
                        'Base Fare',
                        '৳${bus.baseFare.toStringAsFixed(0)}',
                        Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.straighten,
                        'Per KM',
                        '৳${bus.perKmFare.toStringAsFixed(0)}',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (bus.frequency != null) ...[
                  SizedBox(height: 12),
                  _buildInfoChip(
                    Icons.schedule,
                    'Frequency',
                    bus.frequency!,
                    Colors.orange,
                  ),
                ],
                SizedBox(height: 16),
                // Stops Information
                Text(
                  'Bus Stops (${bus.stops.length}):',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bus.stops.length,
                    itemBuilder: (context, index) {
                      final stop = bus.stops[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stop.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            if (stop.latitude != 0 && stop.longitude != 0)
                              Text(
                                '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBusTypeColor(String busType) {
    switch (busType.toLowerCase()) {
      case 'women':
        return Colors.pink;
      case 'general':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

