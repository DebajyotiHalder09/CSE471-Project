const mongoose = require('mongoose');

const individualBusSchema = new mongoose.Schema({
  parentBusInfoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'buses',
    required: true,
  },
  busCode: {
    type: String,
    required: true,
    trim: true,
  },
  totalPassengerCapacity: {
    type: Number,
    required: true,
    default: 0,
  },
  currentPassengerCount: {
    type: Number,
    required: true,
    default: 0,
  },
  latitude: {
    type: Number,
    required: true,
  },
  longitude: {
    type: Number,
    required: true,
  },
  averageSpeedKmh: {
    type: Number,
    required: true,
    default: 25,
  },
  status: {
    type: String,
    enum: ['running', 'stopped', 'maintenance', 'offline'],
    default: 'offline',
  },
}, {
  timestamps: true,
});

const IndividualBus = mongoose.model('buses', individualBusSchema);

module.exports = IndividualBus;
