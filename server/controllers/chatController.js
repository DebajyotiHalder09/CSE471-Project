const Chat = require('../models/chat');
const User = require('../models/user');

// Get or create a chat between two users
const getChat = async (req, res) => {
  try {
    const currentUserId = req.user._id;
    const { otherUserId } = req.params;

    if (!otherUserId) {
      return res.status(400).json({
        success: false,
        message: 'Other user ID is required',
      });
    }

    // Check if other user exists
    const otherUser = await User.findById(otherUserId);
    if (!otherUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    // Find existing chat or create new one
    let chat = await Chat.findOne({
      participants: { $all: [currentUserId, otherUserId] },
    }).populate('participants', 'name email');

    if (!chat) {
      chat = new Chat({
        participants: [currentUserId, otherUserId],
        messages: [],
      });
      await chat.save();
      chat = await Chat.findById(chat._id).populate('participants', 'name email');
    }

    res.status(200).json({
      success: true,
      chat: {
        _id: chat._id,
        participants: chat.participants.map(p => ({
          _id: p._id,
          name: p.name,
          email: p.email,
        })),
        messages: chat.messages.map(m => ({
          _id: m._id,
          senderId: m.senderId,
          text: m.text,
          read: m.read,
          createdAt: m.createdAt,
        })),
        lastMessageAt: chat.lastMessageAt,
        createdAt: chat.createdAt,
      },
    });
  } catch (error) {
    console.error('Error getting chat:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting chat',
      error: error.message,
    });
  }
};

// Send a message
const sendMessage = async (req, res) => {
  try {
    const currentUserId = req.user._id;
    const { chatId, text } = req.body;

    if (!chatId || !text || text.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Chat ID and message text are required',
      });
    }

    // Find the chat
    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({
        success: false,
        message: 'Chat not found',
      });
    }

    // Verify user is a participant
    if (!chat.participants.some(id => id.toString() === currentUserId.toString())) {
      return res.status(403).json({
        success: false,
        message: 'You are not a participant in this chat',
      });
    }

    // Add message
    chat.messages.push({
      senderId: currentUserId,
      text: text.trim(),
    });

    chat.lastMessageAt = new Date();
    await chat.save();

    // Get the newly added message with populated sender
    const newMessage = chat.messages[chat.messages.length - 1];

    res.status(201).json({
      success: true,
      message: {
        _id: newMessage._id,
        senderId: newMessage.senderId,
        text: newMessage.text,
        read: newMessage.read,
        createdAt: newMessage.createdAt,
      },
    });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({
      success: false,
      message: 'Error sending message',
      error: error.message,
    });
  }
};

// Get messages for a chat (with optional pagination)
const getMessages = async (req, res) => {
  try {
    const currentUserId = req.user._id;
    const { chatId } = req.params;

    if (!chatId) {
      return res.status(400).json({
        success: false,
        message: 'Chat ID is required',
      });
    }

    // Find the chat
    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({
        success: false,
        message: 'Chat not found',
      });
    }

    // Verify user is a participant
    if (!chat.participants.some(id => id.toString() === currentUserId.toString())) {
      return res.status(403).json({
        success: false,
        message: 'You are not a participant in this chat',
      });
    }

    // Mark messages as read for the current user
    chat.messages.forEach(message => {
      if (message.senderId.toString() !== currentUserId.toString() && !message.read) {
        message.read = true;
      }
    });
    await chat.save();

    res.status(200).json({
      success: true,
      messages: chat.messages.map(m => ({
        _id: m._id,
        senderId: m.senderId,
        text: m.text,
        read: m.read,
        createdAt: m.createdAt,
      })),
    });
  } catch (error) {
    console.error('Error getting messages:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting messages',
      error: error.message,
    });
  }
};

// Get all chats for the current user (list of conversations)
const getUserChats = async (req, res) => {
  try {
    const currentUserId = req.user._id;

    // Find all chats where user is a participant
    const chats = await Chat.find({
      participants: currentUserId,
    })
      .populate('participants', 'name email')
      .sort({ lastMessageAt: -1 })
      .limit(50);

    // Format response
    const chatList = chats.map(chat => {
      const otherParticipant = chat.participants.find(
        p => p._id.toString() !== currentUserId.toString()
      );
      const lastMessage = chat.messages.length > 0 
        ? chat.messages[chat.messages.length - 1]
        : null;

      return {
        _id: chat._id,
        otherParticipant: {
          _id: otherParticipant._id,
          name: otherParticipant.name,
          email: otherParticipant.email,
        },
        lastMessage: lastMessage ? {
          text: lastMessage.text,
          senderId: lastMessage.senderId,
          createdAt: lastMessage.createdAt,
        } : null,
        lastMessageAt: chat.lastMessageAt,
        unreadCount: chat.messages.filter(
          m => m.senderId.toString() !== currentUserId.toString() && !m.read
        ).length,
      };
    });

    res.status(200).json({
      success: true,
      chats: chatList,
    });
  } catch (error) {
    console.error('Error getting user chats:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting user chats',
      error: error.message,
    });
  }
};

// Get unread message counts for all friends
const getUnreadCounts = async (req, res) => {
  try {
    const currentUserId = req.user._id;

    // Find all chats where user is a participant
    const chats = await Chat.find({
      participants: currentUserId,
    })
      .populate('participants', 'name email');

    // Create a map of friendId -> unreadCount
    const unreadCounts = {};
    
    chats.forEach(chat => {
      const otherParticipant = chat.participants.find(
        p => p._id.toString() !== currentUserId.toString()
      );
      
      if (otherParticipant) {
        const unreadCount = chat.messages.filter(
          m => m.senderId.toString() !== currentUserId.toString() && !m.read
        ).length;
        
        unreadCounts[otherParticipant._id.toString()] = unreadCount;
      }
    });

    res.status(200).json({
      success: true,
      unreadCounts,
    });
  } catch (error) {
    console.error('Error getting unread counts:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting unread counts',
      error: error.message,
    });
  }
};

module.exports = {
  getChat,
  sendMessage,
  getMessages,
  getUserChats,
  getUnreadCounts,
};

