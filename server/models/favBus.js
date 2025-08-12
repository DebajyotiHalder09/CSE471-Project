const mongoose = require('mongoose');

const favBusSchema = new mongoose.Schema({
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
  routeNumber: String,
  operator: String,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

favBusSchema.index({ userId: 1, busId: 1 }, { unique: true });

module.exports = mongoose.model('FavBus', favBusSchema);
