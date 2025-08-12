const mongoose = require('mongoose');

const reviewReplySchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  comment: {
    type: String,
    required: true,
    trim: true,
  },
  likes: [{
    type: String,
  }],
  dislikes: [{
    type: String,
  }],
}, {
  timestamps: true,
});

const reviewSchema = new mongoose.Schema({
  busId: {
    type: String,
    required: true,
  },
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  comment: {
    type: String,
    required: true,
    trim: true,
  },
  likes: [{
    type: String,
  }],
  dislikes: [{
    type: String,
  }],
  replies: [reviewReplySchema],
}, {
  timestamps: true,
});

reviewSchema.virtual('likesCount').get(function() {
  return this.likes.length;
});

reviewSchema.virtual('dislikesCount').get(function() {
  return this.dislikes.length;
});

reviewSchema.virtual('repliesCount').get(function() {
  return this.replies.length;
});

reviewSchema.set('toJSON', { virtuals: true });
reviewSchema.set('toObject', { virtuals: true });

const Review = mongoose.model('review', reviewSchema);

module.exports = Review;
