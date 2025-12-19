const express = require('express');
const router = express.Router();
const {
  getChat,
  sendMessage,
  getMessages,
  getUserChats,
  getUnreadCounts,
} = require('../controllers/chatController');

const verifyToken = require('../middleware/auth');

// Get messages for a specific chat (must come before /:otherUserId)
router.get('/messages/:chatId', verifyToken, getMessages);

// Get unread message counts for all friends
router.get('/unread-counts', verifyToken, getUnreadCounts);

// Get or create a chat between current user and another user
router.get('/:otherUserId', verifyToken, getChat);

// Get all chats for the current user (must come last)
router.get('/', verifyToken, getUserChats);

// Send a message
router.post('/send', verifyToken, sendMessage);

module.exports = router;

