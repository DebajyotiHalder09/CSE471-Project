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
    type: String,
    required: true,
    trim: true,
  }],
}, {
  timestamps: true,
});

const Bus = mongoose.model('buses', busSchema);

module.exports = Bus;
