const mongoose = require('mongoose');

const ridePostSchema = new mongoose.Schema({
  source: {
    type: String,
    required: true,
    trim: true,
  },
  destination: {
    type: String,
    required: true,
    trim: true,
  },
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
    trim: true,
  },
  gender: {
    type: String,
    required: true,
    trim: true,
  },
}, { timestamps: true });

const RidePost = mongoose.model('rideshare', ridePostSchema);

module.exports = RidePost;
