const mongoose = require('mongoose');

const rideRequestSchema = new mongoose.Schema({
  ridePostId: {
    type: String,
    required: true,
    ref: 'RidePost'
  },
  requesterId: {
    type: String,
    required: true,
    ref: 'User'
  },
  requesterName: {
    type: String,
    required: true
  },
  requesterGender: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending'
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('RideRequest', rideRequestSchema);
