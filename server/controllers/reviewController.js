const Review = require('../models/review');

const reviewController = {
  getReviewsByBusId: async (req, res) => {
    try {
      const { busId } = req.params;
      console.log('Fetching reviews for busId:', busId);
      
      // The busId parameter is actually the _id from bus_info collection
      const reviews = await Review.find({ busId: busId })
        .sort({ createdAt: -1 });

      console.log('Found reviews:', reviews.length);

      res.json({
        success: true,
        reviews: reviews.map(review => ({
          _id: review._id,
          busId: review.busId,
          userId: review.userId,
          userName: review.userName,
          comment: review.comment,
          createdAt: review.createdAt,
          likes: review.likes ? review.likes.length : 0,
          dislikes: review.dislikes ? review.dislikes.length : 0,
          replies: review.replies ? review.replies.length : 0,
          repliesList: review.replies ? review.replies.map(reply => ({
            _id: reply._id,
            userId: reply.userId,
            userName: reply.userName,
            comment: reply.comment,
            createdAt: reply.createdAt,
            likes: reply.likes ? reply.likes.length : 0,
            dislikes: reply.dislikes ? reply.dislikes.length : 0,
          })) : [],
        })),
      });
    } catch (error) {
      console.error('Error fetching reviews:', error);
      res.status(500).json({
        success: false,
        message: 'Error fetching reviews',
        error: error.message,
      });
    }
  },

  createReview: async (req, res) => {
    try {
      const { busId, userId, userName, comment } = req.body;
      console.log('Creating review with data:', { busId, userId, userName, comment });

      if (!busId || !userId || !userName || !comment) {
        return res.status(400).json({
          success: false,
          message: 'All fields are required',
        });
      }

      // busId here is actually the _id from bus_info collection
      const review = new Review({
        busId: busId,
        userId: userId,
        userName: userName,
        comment: comment,
        likes: [],
        dislikes: [],
        replies: [],
      });

      console.log('Review object created:', review);
      await review.save();
      console.log('Review saved successfully:', review._id);

      res.status(201).json({
        success: true,
        review: {
          _id: review._id,
          busId: review.busId,
          userId: review.userId,
          userName: review.userName,
          comment: review.comment,
          createdAt: review.createdAt,
          likes: 0,
          dislikes: 0,
          replies: 0,
          repliesList: [],
        },
      });
    } catch (error) {
      console.error('Error creating review:', error);
      res.status(500).json({
        success: false,
        message: 'Error creating review',
        error: error.message,
      });
    }
  },

  likeReview: async (req, res) => {
    try {
      const { reviewId } = req.params;
      const { userId } = req.body;

      const review = await Review.findById(reviewId);
      if (!review) {
        return res.status(404).json({
          success: false,
          message: 'Review not found',
        });
      }

      const likeIndex = review.likes.indexOf(userId);
      const dislikeIndex = review.dislikes.indexOf(userId);

      if (likeIndex > -1) {
        review.likes.splice(likeIndex, 1);
      } else {
        if (dislikeIndex > -1) {
          review.dislikes.splice(dislikeIndex, 1);
        }
        review.likes.push(userId);
      }

      await review.save();

      res.json({
        success: true,
        likes: review.likes ? review.likes.length : 0,
        dislikes: review.dislikes ? review.dislikes.length : 0,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error updating like',
        error: error.message,
      });
    }
  },

  dislikeReview: async (req, res) => {
    try {
      const { reviewId } = req.params;
      const { userId } = req.body;

      const review = await Review.findById(reviewId);
      if (!review) {
        return res.status(404).json({
          success: false,
          message: 'Review not found',
        });
      }

      const dislikeIndex = review.dislikes.indexOf(userId);
      const likeIndex = review.likes.indexOf(userId);

      if (dislikeIndex > -1) {
        review.dislikes.splice(dislikeIndex, 1);
      } else {
        if (likeIndex > -1) {
          review.likes.splice(likeIndex, 1);
        }
        review.dislikes.push(userId);
      }

      await review.save();

      res.json({
        success: true,
        likes: review.likes ? review.likes.length : 0,
        dislikes: review.dislikes ? review.dislikes.length : 0,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error updating dislike',
        error: error.message,
      });
    }
  },

  addReply: async (req, res) => {
    try {
      const { reviewId } = req.params;
      const { userId, userName, comment } = req.body;

      if (!userId || !userName || !comment) {
        return res.status(400).json({
          success: false,
          message: 'All fields are required',
        });
      }

      const review = await Review.findById(reviewId);
      if (!review) {
        return res.status(404).json({
          success: false,
          message: 'Review not found',
        });
      }

      const reply = {
        userId,
        userName,
        comment,
        likes: [],
        dislikes: [],
      };

      review.replies.push(reply);
      await review.save();

      res.json({
        success: true,
        reply: {
          _id: reply._id,
          userId: reply.userId,
          userName: reply.userName,
          comment: reply.comment,
          createdAt: reply.createdAt,
          likes: 0,
          dislikes: 0,
        },
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error adding reply',
        error: error.message,
      });
    }
  },
};

module.exports = reviewController;
