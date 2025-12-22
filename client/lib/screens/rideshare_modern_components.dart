import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/user.dart';

/// Modern ride post card with gradient and animations
class ModernRideCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final User? currentUser;
  final Map<String, String> userRequestStatus;
  final Map<String, List<Map<String, dynamic>>> rideRequests;
  final VoidCallback? onRequestJoin;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  final Widget? fareDisplay;
  final Widget? participantsSection;
  final Widget? requestsSection;

  const ModernRideCard({
    super.key,
    required this.post,
    this.currentUser,
    this.userRequestStatus = const {},
    this.rideRequests = const {},
    this.onRequestJoin,
    this.onDelete,
    this.onChat,
    this.fareDisplay,
    this.participantsSection,
    this.requestsSection,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnPost = currentUser?.id == post['userId']?.toString();
    final requestStatus = userRequestStatus[post['_id']?.toString() ?? ''];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.modernCardDecoration(
        shadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlueLight,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['userName'] ?? 'Unknown User',
                          style: AppTheme.heading4.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(DateTime.parse(
                                post['createdAt'] ?? DateTime.now().toIso8601String(),
                              )),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOwnPost)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: onDelete,
                      tooltip: 'Delete ride',
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route information
                  _buildRouteSection(),
                  const SizedBox(height: 20),
                  // Fare display
                  if (fareDisplay != null) fareDisplay!,
                  const SizedBox(height: 16),
                  // Participants
                  if (participantsSection != null) participantsSection!,
                  const SizedBox(height: 16),
                  // Action buttons
                  _buildActionButtons(context, isOwnPost, requestStatus),
                  // Requests section for own posts
                  if (isOwnPost && requestsSection != null) ...[
                    const SizedBox(height: 16),
                    requestsSection!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: AppTheme.accentGreen,
            label: 'From',
            location: post['source'] ?? 'Unknown location',
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppTheme.borderLight,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.flag,
            iconColor: AppTheme.accentRed,
            label: 'To',
            location: post['destination'] ?? 'Unknown location',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isOwnPost,
    String? requestStatus,
  ) {
    // Removed chat button from post card as requested
    if (isOwnPost) {
      return const SizedBox.shrink();
    }

    // Check if ride is full
    final maxParticipants = post['maxParticipants'] ?? 3;
    final participants = post['participants'] as List<dynamic>? ?? [];
    final currentCount = participants.length;
    final isFull = currentCount >= maxParticipants;

    if (requestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentOrange),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: AppTheme.accentOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Request Pending',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.accentOrange,
              ),
            ),
          ],
        ),
      );
    }

    if (requestStatus == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentGreen),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Request Accepted',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.accentGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (requestStatus == 'rejected') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentRed),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: AppTheme.accentRed, size: 20),
            const SizedBox(width: 8),
            Text(
              'Request Rejected',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.accentRed,
              ),
            ),
          ],
        ),
      );
    }

    // Show "Ride Full" if the ride is full
    if (isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentRed),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, color: AppTheme.accentRed, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ride Full ($currentCount/$maxParticipants)',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.accentRed,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onRequestJoin,
        icon: const Icon(Icons.person_add),
        label: const Text('Request to Join'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
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
}

/// Modern fare display widget
class ModernFareDisplay extends StatelessWidget {
  final double? distance;
  final double? fare;
  final double? individualFare;
  final int participantCount;

  const ModernFareDisplay({
    super.key,
    this.distance,
    this.fare,
    this.individualFare,
    this.participantCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (distance == null || fare == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentGreen.withOpacity(0.1),
            AppTheme.primaryBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.attach_money,
              color: AppTheme.accentGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten, color: AppTheme.primaryBlue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${distance!.toStringAsFixed(1)} km',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '৳${fare!.toStringAsFixed(0)}',
                  style: AppTheme.heading4.copyWith(
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (participantCount > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '৳${individualFare!.toStringAsFixed(0)} per person (${participantCount} participants)',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern participants section
class ModernParticipantsSection extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final int? maxParticipants;
  final Function(String userId, String userName)? onParticipantTap;

  const ModernParticipantsSection({
    super.key,
    required this.participants,
    this.maxParticipants,
    this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final max = maxParticipants ?? 3;
    final currentCount = participants.length;
    final isFull = currentCount >= max;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFull 
            ? AppTheme.accentRed.withOpacity(0.05)
            : AppTheme.accentGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFull
              ? AppTheme.accentRed.withOpacity(0.2)
              : AppTheme.accentGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFull ? Icons.people_outline : Icons.people,
                color: isFull ? AppTheme.accentRed : AppTheme.accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Participants ($currentCount/$max)',
                style: AppTheme.labelLarge.copyWith(
                  color: isFull ? AppTheme.accentRed : AppTheme.accentGreen,
                ),
              ),
              if (isFull) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FULL',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: participants.map((participant) {
              final userName = participant['userName'] ?? participant['requesterName'] ?? 'Unknown';
              final userId = participant['userId']?.toString() ?? participant['requesterId']?.toString() ?? '';
              final isCreator = participant['isCreator'] == true;
              
              return InkWell(
                onTap: onParticipantTap != null && userId.isNotEmpty
                    ? () => onParticipantTap!(userId, userName)
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCreator 
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCreator
                          ? AppTheme.primaryBlue.withOpacity(0.3)
                          : AppTheme.accentGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: isCreator
                            ? AppTheme.primaryBlue.withOpacity(0.2)
                            : AppTheme.accentGreen.withOpacity(0.2),
                        radius: 14,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: TextStyle(
                            color: isCreator ? AppTheme.primaryBlue : AppTheme.accentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userName,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isCreator) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: AppTheme.primaryBlue,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Modern post ride form card
class ModernPostRideCard extends StatelessWidget {
  final TextEditingController sourceController;
  final TextEditingController destinationController;
  final bool isLoading;
  final bool isFareCalculating;
  final double? estimatedDistance;
  final double? estimatedFare;
  final User? currentUser;
  final VoidCallback? onPostRide;
  final VoidCallback? onCalculateFare;
  final bool hasExistingPost;
  final Widget? existingPostCard;
  final VoidCallback? onDeletePost;
  final ValueChanged<String>? onSourceChanged;
  final ValueChanged<String>? onDestinationChanged;

  const ModernPostRideCard({
    super.key,
    required this.sourceController,
    required this.destinationController,
    this.isLoading = false,
    this.isFareCalculating = false,
    this.estimatedDistance,
    this.estimatedFare,
    this.currentUser,
    this.onPostRide,
    this.onCalculateFare,
    this.hasExistingPost = false,
    this.existingPostCard,
    this.onDeletePost,
    this.onSourceChanged,
    this.onDestinationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: AppTheme.modernCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_road,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post a Ride',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your journey with others',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (hasExistingPost && existingPostCard != null) ...[
              existingPostCard!,
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDeletePost,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Current Post'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: BorderSide(color: AppTheme.accentRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: sourceController,
                onChanged: onSourceChanged,
                decoration: InputDecoration(
                  labelText: 'From',
                  hintText: 'Enter source location',
                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.accentGreen),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: destinationController,
                onChanged: onDestinationChanged,
                decoration: InputDecoration(
                  labelText: 'To',
                  hintText: 'Enter destination location',
                  prefixIcon: const Icon(Icons.flag, color: AppTheme.accentRed),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                ),
              ),
              const SizedBox(height: 20),
              // Fare estimation card
              _buildFareEstimationCard(),
              const SizedBox(height: 20),
              // Post button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLoading || currentUser == null) ? null : onPostRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentUser == null
                        ? AppTheme.textTertiary
                        : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          currentUser == null ? 'Login Required' : 'Post Ride',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFareEstimationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fare Estimation',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isFareCalculating)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Calculating fare...',
                  style: AppTheme.bodyMedium,
                ),
              ],
            )
          else if (estimatedFare != null && estimatedDistance != null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${estimatedDistance!.toStringAsFixed(1)} km',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '৳${estimatedFare!.toStringAsFixed(0)}',
                        style: AppTheme.heading4.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '৳30 per km',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceController.text.trim().isNotEmpty &&
                          destinationController.text.trim().isNotEmpty
                      ? 'Click to calculate fare'
                      : 'Enter locations to see fare',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (onCalculateFare != null &&
                    sourceController.text.trim().isNotEmpty &&
                    destinationController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCalculateFare,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryBlue),
                      ),
                      child: const Text('Calculate Fare'),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

