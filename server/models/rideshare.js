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
  participants: [{
    userId: String,
    userName: String,
    gender: String,
    joinedAt: {
      type: Date,
      default: Date.now
    }
  }],
  maxParticipants: {
    type: Number,
    default: 3
  },
}, { timestamps: true });

// Pre-save middleware to ensure creator is always first participant
ridePostSchema.pre('save', function(next) {
  if (this.isNew) {
    // When creating a new ride post, add the creator as the first participant
    this.participants = [{
      userId: this.userId,
      userName: this.userName,
      gender: this.gender,
      joinedAt: new Date()
    }];
  }
  next();
});

const RidePost = mongoose.model('rideshare', ridePostSchema);

module.exports = RidePost;
