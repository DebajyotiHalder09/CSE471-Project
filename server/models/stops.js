const mongoose = require('mongoose');

const stopSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  search: {
    type: String,
    required: true,
    trim: true,
    lowercase: true,
  },
  lat: {
    type: Number,
    required: true,
  },
  lng: {
    type: Number,
    required: true,
  },
}, {
  timestamps: false,
});

// Create index on search field for fast prefix searches
stopSchema.index({ search: 1 });
// Create geospatial index for distance queries (if needed in future)
stopSchema.index({ lat: 1, lng: 1 });

const Stop = mongoose.model('Stop', stopSchema, 'stops');

module.exports = Stop;

