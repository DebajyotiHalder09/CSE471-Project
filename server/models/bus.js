const mongoose = require('mongoose');

const busSchema = new mongoose.Schema({
  busName: {
    type: String,
    required: true,
    trim: true,
  },
  routeNumber: {
    type: String,
    trim: true,
  },
  operator: {
    type: String,
    trim: true,
  },
  frequency: {
    type: String,
    trim: true,
  },
  stops: [{
    name: {
      type: String,
      required: true,
      trim: true,
    },
    lat: {
      type: Number,
      required: true,
    },
    lng: {
      type: Number,
      required: true,
    },
  }],
  base_fare: {
    type: Number,
    required: true,
    default: 0,
  },
  per_km_fare: {
    type: Number,
    required: true,
    default: 0,
  },
}, {
  timestamps: true,
});

const Bus = mongoose.model('buses', busSchema);

module.exports = Bus;
