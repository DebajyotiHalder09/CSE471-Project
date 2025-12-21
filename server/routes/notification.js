const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

// Create notification
router.post('/', notificationController.createNotification);

// Get user notifications
router.get('/user/:userId', notificationController.getUserNotifications);

// Get unread count
router.get('/unread/:userId', notificationController.getUnreadCount);

// Mark as read
router.patch('/read/:notificationId', notificationController.markAsRead);

// Mark all as read
router.patch('/read-all', notificationController.markAllAsRead);

// Delete notification
router.delete('/:notificationId', notificationController.deleteNotification);

// Delete all notifications
router.delete('/user/:userId', notificationController.deleteAllNotifications);

// Create SOS notification for all users
router.post('/sos', notificationController.createSOSNotification);

module.exports = router;

