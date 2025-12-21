const mongoose = require('mongoose');

const fareSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  source: {
    type: String,
    required: true,
    index: true
  },
  destination: {
    type: String,
    required: true,
    index: true
  },
  distance: {
    type: Number,
    required: true
  },
  sourceCoordinates: {
    lat: {
      type: Number,
      required: false
    },
    lon: {
      type: Number,
      required: false
    }
  },
  destinationCoordinates: {
    lat: {
      type: Number,
      required: false
    },
    lon: {
      type: Number,
      required: false
    }
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 86400 * 7 // Auto-delete after 7 days
  }
}, {
  timestamps: true
});

// Compound index for faster lookups
fareSchema.index({ userId: 1, source: 1, destination: 1 });
fareSchema.index({ source: 1, destination: 1 }); // For general lookups

const Fare = mongoose.model('Fare', fareSchema);

module.exports = Fare;

