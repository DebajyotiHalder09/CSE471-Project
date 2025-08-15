const mongoose = require('mongoose');

const tripSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  busId: {
    type: String,
    required: true,
    index: true
  },
  busName: {
    type: String,
    required: true
  },
  distance: {
    type: Number,
    required: true
  },
  fare: {
    type: Number,
    required: true
  },
  source: {
    type: String,
    required: true
  },
  destination: {
    type: String,
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  collection: 'travelStats'
});

module.exports = mongoose.model('Trip', tripSchema);
