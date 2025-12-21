import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import '../utils/error_widgets.dart';
import '../utils/loading_widgets.dart';
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
    // Poll for new notifications every 15 seconds
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadNotifications();
        _loadUnreadCount();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await NotificationService.getUserNotifications();
      if (result['success']) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await NotificationService.getUnreadCount();
      if (result['success'] && mounted) {
        setState(() {
          _unreadCount = result['count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final result = await NotificationService.markAsRead(notificationId);
      if (result['success']) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['_id'] == notificationId,
          );
          if (index != -1) {
            _notifications[index]['isRead'] = true;
            if (_unreadCount > 0) {
              _unreadCount--;
            }
          }
        });
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final result = await NotificationService.markAllAsRead();
      if (result['success']) {
        setState(() {
          for (var notification in _notifications) {
            notification['isRead'] = true;
          }
          _unreadCount = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All notifications marked as read'),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final result = await NotificationService.deleteNotification(notificationId);
      if (result['success']) {
        setState(() {
          _notifications.removeWhere((n) => n['_id'] == notificationId);
          if (_unreadCount > 0 && _notifications.any((n) => n['_id'] == notificationId && !n['isRead'])) {
            _unreadCount--;
          }
        });
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'success':
        return AppTheme.accentGreen;
      case 'warning':
        return AppTheme.accentOrange;
      case 'error':
        return AppTheme.accentRed;
      case 'ride':
        return AppTheme.primaryBlue;
      case 'trip':
        return AppTheme.accentPurple;
      case 'payment':
        return AppTheme.accentGreen;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline;
      case 'ride':
        return Icons.directions_car;
      case 'trip':
        return Icons.route;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.info_outline;
    }
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

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? 'info';
    final typeColor = _getTypeColor(type);
    final createdAt = notification['createdAt'] != null
        ? DateTime.tryParse(notification['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.modernCardDecorationDark(context).copyWith(
        color: isRead
            ? (isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite)
            : (isDark ? AppTheme.darkSurfaceElevated : AppTheme.primaryBlue.withOpacity(0.05)),
        border: isRead
            ? null
            : Border.all(
                color: typeColor.withOpacity(0.3),
                width: 1.5,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (!isRead) {
              await _markAsRead(notification['_id']);
            }
            // Navigate to action URL if available
            if (notification['actionUrl'] != null) {
              // Handle navigation based on actionUrl
              // This can be customized based on your routing needs
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        typeColor,
                        typeColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'Notification',
                              style: AppTheme.heading4Dark(context).copyWith(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                color: isRead
                                    ? (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)
                                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: typeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification['message'] ?? '',
                        style: AppTheme.bodyMediumDark(context).copyWith(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _formatDate(createdAt),
                            style: AppTheme.bodySmallDark(context).copyWith(
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                            ),
                            onPressed: () => _deleteNotification(notification['_id']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlueLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Notifications',
                      style: AppTheme.heading3Dark(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentRed,
                            AppTheme.accentRed.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_unreadCount new',
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadNotifications();
              _loadUnreadCount();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadNotifications();
          await _loadUnreadCount();
        },
        child: _isLoading
            ? const LoadingWidget()
            : _errorMessage != null
                ? ErrorDisplayWidget(
                    message: _errorMessage!,
                    onRetry: _loadNotifications,
                  )
                : _notifications.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notifications_none,
                        title: 'No Notifications',
                        message: 'You\'re all caught up!',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          return _buildNotificationCard(_notifications[index]);
                        },
                      ),
      ),
    );
  }
}

