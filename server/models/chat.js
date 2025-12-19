const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  text: {
    type: String,
    required: true,
    trim: true,
  },
  read: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
});

const chatSchema = new mongoose.Schema({
  participants: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  }],
  messages: [messageSchema],
  lastMessageAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

// Index for faster queries by participants
chatSchema.index({ participants: 1 });
chatSchema.index({ lastMessageAt: -1 });

// Ensure participants array always has exactly 2 unique users
chatSchema.pre('save', function(next) {
  if (this.participants.length !== 2) {
    return next(new Error('Chat must have exactly 2 participants'));
  }
  // Sort participants to ensure consistent ordering for queries
  this.participants.sort();
  next();
});

const Chat = mongoose.model('Chat', chatSchema);

module.exports = Chat;

