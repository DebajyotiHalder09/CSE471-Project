const Notification = require('../models/notification');
const User = require('../models/user');

const notificationController = {
  // Create a new notification
  createNotification: async (req, res) => {
    try {
      const { userId, title, message, type = 'info', data = null, actionUrl = null } = req.body;
      
      if (!userId || !title || !message) {
        return res.status(400).json({
          success: false,
          message: 'userId, title, and message are required',
        });
      }

      const notification = new Notification({
        userId: userId,
        title: title,
        message: message,
        type: type,
        data: data,
        actionUrl: actionUrl,
      });

      await notification.save();

      res.status(201).json({
        success: true,
        data: {
          _id: notification._id,
          userId: notification.userId,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          isRead: notification.isRead,
          data: notification.data,
          actionUrl: notification.actionUrl,
          createdAt: notification.createdAt,
        },
      });
    } catch (error) {
      console.error('Error creating notification:', error);
      res.status(500).json({
        success: false,
        message: 'Error creating notification',
        error: error.message,
      });
    }
  },

  // Get all notifications for a user
  getUserNotifications: async (req, res) => {
    try {
      const { userId } = req.params;
      const { limit = 50, unreadOnly = false } = req.query;
      
      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'userId is required',
        });
      }

      const query = { userId: userId };
      if (unreadOnly === 'true') {
        query.isRead = false;
      }

      const notifications = await Notification.find(query)
        .sort({ createdAt: -1 })
        .limit(parseInt(limit));

      res.json({
        success: true,
        data: notifications.map(notif => ({
          _id: notif._id,
          userId: notif.userId,
          title: notif.title,
          message: notif.message,
          type: notif.type,
          isRead: notif.isRead,
          data: notif.data,
          actionUrl: notif.actionUrl,
          createdAt: notif.createdAt,
        })),
      });
    } catch (error) {
      console.error('Error getting notifications:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting notifications',
        error: error.message,
      });
    }
  },

  // Get unread notification count
  getUnreadCount: async (req, res) => {
    try {
      const { userId } = req.params;
      
      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'userId is required',
        });
      }

      const count = await Notification.countDocuments({
        userId: userId,
        isRead: false,
      });

      res.json({
        success: true,
        count: count,
      });
    } catch (error) {
      console.error('Error getting unread count:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting unread count',
        error: error.message,
      });
    }
  },

  // Mark notification as read
  markAsRead: async (req, res) => {
    try {
      const { notificationId } = req.params;
      
      const notification = await Notification.findByIdAndUpdate(
        notificationId,
        { isRead: true },
        { new: true }
      );

      if (!notification) {
        return res.status(404).json({
          success: false,
          message: 'Notification not found',
        });
      }

      res.json({
        success: true,
        data: {
          _id: notification._id,
          isRead: notification.isRead,
        },
      });
    } catch (error) {
      console.error('Error marking notification as read:', error);
      res.status(500).json({
        success: false,
        message: 'Error marking notification as read',
        error: error.message,
      });
    }
  },

  // Mark all notifications as read
  markAllAsRead: async (req, res) => {
    try {
      const { userId } = req.body;
      
      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'userId is required',
        });
      }

      const result = await Notification.updateMany(
        { userId: userId, isRead: false },
        { isRead: true }
      );

      res.json({
        success: true,
        message: `Marked ${result.modifiedCount} notifications as read`,
        count: result.modifiedCount,
      });
    } catch (error) {
      console.error('Error marking all as read:', error);
      res.status(500).json({
        success: false,
        message: 'Error marking all as read',
        error: error.message,
      });
    }
  },

  // Delete a notification
  deleteNotification: async (req, res) => {
    try {
      const { notificationId } = req.params;
      
      const notification = await Notification.findByIdAndDelete(notificationId);

      if (!notification) {
        return res.status(404).json({
          success: false,
          message: 'Notification not found',
        });
      }

      res.json({
        success: true,
        message: 'Notification deleted successfully',
      });
    } catch (error) {
      console.error('Error deleting notification:', error);
      res.status(500).json({
        success: false,
        message: 'Error deleting notification',
        error: error.message,
      });
    }
  },

  // Delete all notifications for a user
  deleteAllNotifications: async (req, res) => {
    try {
      const { userId } = req.params;
      
      const result = await Notification.deleteMany({ userId: userId });

      res.json({
        success: true,
        message: `Deleted ${result.deletedCount} notifications`,
        count: result.deletedCount,
      });
    } catch (error) {
      console.error('Error deleting all notifications:', error);
      res.status(500).json({
        success: false,
        message: 'Error deleting all notifications',
        error: error.message,
      });
    }
  },

  // Create SOS notification for all users
  createSOSNotification: async (req, res) => {
    try {
      const { userId, userName, source, latitude, longitude, serviceType, serviceName } = req.body;
      
      if (!userId || !userName || !source) {
        return res.status(400).json({
          success: false,
          message: 'userId, userName, and source are required',
        });
      }

      // Get all users except the one who sent the SOS
      const allUsers = await User.find({ _id: { $ne: userId } }, '_id');
      
      if (allUsers.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'No other users found',
        });
      }

      // Determine notification title and type based on service
      let notificationTitle = '🚨 SOS Alert';
      let notificationType = 'error';
      let notificationMessage = `${userName} needs help at ${source}`;

      if (serviceType === 'ambulance') {
        notificationTitle = '🚑 Ambulance Request';
        notificationType = 'ride';
        notificationMessage = `${userName} requested ambulance at ${source}`;
      } else if (serviceType === 'police') {
        notificationTitle = '🚔 Police Request';
        notificationType = 'warning';
        notificationMessage = `${userName} requested police at ${source}`;
      } else if (serviceType === 'fire') {
        notificationTitle = '🚒 Fire Emergency';
        notificationType = 'error';
        notificationMessage = `${userName} reported fire emergency at ${source}`;
      } else {
        notificationMessage = `${userName} needs help at ${source}`;
      }

      // Create notification for each user (excluding the sender)
      const notifications = allUsers.map(user => ({
        userId: user._id,
        title: notificationTitle,
        message: notificationMessage + (latitude && longitude ? ` (${latitude}, ${longitude})` : ''),
        type: notificationType,
        isRead: false,
        data: {
          sosUserId: userId,
          sosUserName: userName,
          source: source,
          latitude: latitude,
          longitude: longitude,
          serviceType: serviceType || 'trigger',
          serviceName: serviceName || 'Emergency',
          timestamp: new Date(),
        },
        actionUrl: latitude && longitude ? `https://maps.google.com/?q=${latitude},${longitude}` : null,
      }));

      // Insert all notifications
      const createdNotifications = await Notification.insertMany(notifications);

      res.status(201).json({
        success: true,
        message: `SOS notification sent to ${createdNotifications.length} users`,
        count: createdNotifications.length,
        data: {
          _id: createdNotifications[0]._id,
          userId: userId,
          userName: userName,
          source: source,
        },
      });
    } catch (error) {
      console.error('Error creating SOS notification:', error);
      res.status(500).json({
        success: false,
        message: 'Error creating SOS notification',
        error: error.message,
      });
    }
  },
};

module.exports = notificationController;

