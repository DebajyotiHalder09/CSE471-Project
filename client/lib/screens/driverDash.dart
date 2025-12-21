import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/rideshare_service.dart';
import '../utils/app_theme.dart';
import '../utils/error_widgets.dart';
import '../utils/loading_widgets.dart';

class DriverDashScreen extends StatefulWidget {
  const DriverDashScreen({super.key});

  @override
  State<DriverDashScreen> createState() => _DriverDashScreenState();
}

class _DriverDashScreenState extends State<DriverDashScreen> {
  List<Map<String, dynamic>> ridePosts = [];
  bool isLoading = false;
  String? errorMessage;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadRidePosts();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getUser();
      setState(() {
        currentUser = user;
      });
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadRidePosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await RideshareService.getAllRidePosts();
      if (response['success']) {
        setState(() {
          ridePosts = List<Map<String, dynamic>>.from(response['data']);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load ride posts';
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

  void _acceptRide(Map<String, dynamic> ridePost) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ride accepted! Implementation coming soon.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  int _getCurrentParticipantCount(Map<String, dynamic> post) {
    final participants = post['participants'] ?? [];
    return participants.length;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildRideCard(Map<String, dynamic> post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final participantCount = _getCurrentParticipantCount(post);
    final maxParticipants = post['maxParticipants'] ?? 3;
    final isFull = participantCount >= maxParticipants;
    final distance = post['distance'] != null ? (post['distance'] is num ? post['distance'].toDouble() : double.tryParse(post['distance'].toString()) ?? 0.0) : 0.0;
    final fare = post['fare'] != null ? (post['fare'] is num ? post['fare'].toDouble() : double.tryParse(post['fare'].toString()) ?? 0.0) : 0.0;
    final createdAt = post['createdAt'] != null 
        ? DateTime.tryParse(post['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.modernCardDecorationDark(context).copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show ride details modal
            _showRideDetailsModal(post);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: User info and time
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlueLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          post['userName']?.isNotEmpty == true
                              ? post['userName'][0].toUpperCase()
                              : 'U',
                          style: AppTheme.heading4.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['userName'] ?? 'Unknown User',
                            style: AppTheme.heading4Dark(context).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: post['gender']?.toString().toLowerCase() == 'male'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.pink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      post['gender']?.toString().toLowerCase() == 'male'
                                          ? Icons.male
                                          : Icons.female,
                                      size: 14,
                                      color: post['gender']?.toString().toLowerCase() == 'male'
                                          ? Colors.blue[700]
                                          : Colors.pink[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post['gender'] ?? 'Not specified',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: post['gender']?.toString().toLowerCase() == 'male'
                                            ? Colors.blue[700]
                                            : Colors.pink[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(createdAt),
                                style: AppTheme.bodySmallDark(context).copyWith(
                                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isFull)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          'FULL',
                          style: AppTheme.labelSmall.copyWith(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Route information with gradient icons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Source
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentGreen,
                                  AppTheme.accentGreen.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Source',
                                  style: AppTheme.bodySmallDark(context).copyWith(
                                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post['source'] ?? 'Unknown location',
                                  style: AppTheme.bodyLargeDark(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Destination
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentRed,
                                  AppTheme.accentRed.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Destination',
                                  style: AppTheme.bodySmallDark(context).copyWith(
                                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post['destination'] ?? 'Unknown location',
                                  style: AppTheme.bodyLargeDark(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Distance, Fare, and Participants
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.straighten_rounded, color: AppTheme.primaryBlue, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              distance > 0 ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentGreen,
                              AppTheme.accentGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('৳', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(
                              fare > 0 ? fare.toStringAsFixed(0) : 'N/A',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_rounded, color: Colors.orange[700], size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$participantCount/$maxParticipants',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Participants List
                if (post['participants'] != null && post['participants'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_outline, color: AppTheme.accentGreen, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Participants',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.accentGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...post['participants'].map<Widget>((participant) {
                          final isCreator = participant['userId'] == post['userId'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: isCreator
                                        ? LinearGradient(
                                            colors: [Colors.orange[400]!, Colors.orange[600]!],
                                          )
                                        : LinearGradient(
                                            colors: [AppTheme.accentGreen, AppTheme.accentGreen.withOpacity(0.8)],
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isCreator ? Icons.star : Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        participant['userName'] ?? 'Unknown',
                                        style: AppTheme.bodyMediumDark(context).copyWith(
                                          fontWeight: isCreator ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      if (participant['gender'] != null)
                                        Text(
                                          participant['gender'],
                                          style: AppTheme.bodySmallDark(context).copyWith(
                                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Accept Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isFull
                        ? null
                        : () => _acceptRide(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFull
                          ? Colors.grey[400]
                          : null,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: isFull ? 0 : 4,
                    ).copyWith(
                      backgroundColor: isFull
                          ? MaterialStateProperty.all(Colors.grey[400])
                          : MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.pressed)) {
                                return AppTheme.accentGreen.withOpacity(0.8);
                              }
                              return AppTheme.accentGreen;
                            }),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFull ? Icons.block : Icons.check_circle_outline,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFull ? 'Ride Full' : 'Accept Ride',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRideDetailsModal(Map<String, dynamic> post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride Details',
                      style: AppTheme.heading3Dark(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRideCard(post),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentGreen,
                    AppTheme.accentGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Driver Dashboard',
              style: AppTheme.heading3Dark(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRidePosts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRidePosts,
        child: isLoading
            ? const LoadingWidget()
            : errorMessage != null
                ? ErrorDisplayWidget(
                    message: errorMessage!,
                    onRetry: _loadRidePosts,
                  )
                : ridePosts.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.directions_car_outlined,
                        title: 'No Rides Available',
                        message: 'Check back later for new ride requests',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: ridePosts.length,
                        itemBuilder: (context, index) {
                          return _buildRideCard(ridePosts[index]);
                        },
                      ),
      ),
    );
  }
}
