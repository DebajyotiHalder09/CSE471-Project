import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Confirmation dialog utility
class ConfirmationDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: confirmColor ?? AppTheme.accentRed,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTheme.heading4,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppTheme.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Delete confirmation
  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
  }) async {
    return show(
      context: context,
      title: 'Delete $itemName?',
      message: 'Are you sure you want to delete this? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppTheme.accentRed,
      icon: Icons.delete_outline,
    );
  }

  /// Logout confirmation
  static Future<bool> showLogout({
    required BuildContext context,
  }) async {
    return show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      confirmColor: AppTheme.accentOrange,
      icon: Icons.logout,
    );
  }

  /// Payment confirmation
  static Future<bool> showPayment({
    required BuildContext context,
    required double amount,
  }) async {
    return show(
      context: context,
      title: 'Confirm Payment',
      message: 'Do you want to proceed with payment of ৳${amount.toStringAsFixed(2)}?',
      confirmText: 'Pay',
      confirmColor: AppTheme.accentGreen,
      icon: Icons.payment,
    );
  }
}

