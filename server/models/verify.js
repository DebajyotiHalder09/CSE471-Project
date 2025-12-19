const mongoose = require('mongoose');

const verifySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  userEmail: {
    type: String,
    required: true,
  },
  institutionName: {
    type: String,
    required: true,
  },
  institutionId: {
    type: String,
    required: true,
  },
  gmail: {
    type: String,
    required: true,
  },
  imageUrl: {
    type: String,
    required: false,
  },
  status: {
    type: String,
    enum: ['hold', 'approved', 'rejected'],
    default: 'hold',
  },
}, {
  timestamps: true
});

const Verify = mongoose.model('Verify', verifySchema);

module.exports = Verify;

