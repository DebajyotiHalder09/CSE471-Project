const RidePost = require('../models/rideshare');
const { addGemsToUser } = require('./walletController');

const rideshareController = {
  createRidePost: async (req, res) => {
    try {
      const { source, destination, userId, userName, gender } = req.body;
      
      if (!source || !destination || !userId || !userName || !gender) {
        return res.status(400).json({
          success: false,
          message: 'All fields are required',
        });
      }

      const ridePost = new RidePost({
        source,
        destination,
        userId,
        userName,
        gender,
      });

      await ridePost.save();

      res.status(201).json({
        success: true,
        ridePost: {
          _id: ridePost._id,
          source: ridePost.source,
          destination: ridePost.destination,
          userId: ridePost.userId,
          userName: ridePost.userName,
          gender: ridePost.gender,
          createdAt: ridePost.createdAt,
        },
      });
    } catch (error) {
      console.error('Error creating ride post:', error);
      res.status(500).json({
        success: false,
        message: 'Error creating ride post',
        error: error.message,
      });
    }
  },

  getAllRidePosts: async (req, res) => {
    try {
      const ridePosts = await RidePost.find().sort({ createdAt: -1 });

      res.json({
        success: true,
        data: ridePosts.map(post => ({
          _id: post._id,
          source: post.source,
          destination: post.destination,
          userId: post.userId,
          userName: post.userName,
          gender: post.gender,
          participants: post.participants || [],
          maxParticipants: post.maxParticipants || 3,
          createdAt: post.createdAt,
        })),
      });
    } catch (error) {
      console.error('Error fetching ride posts:', error);
      res.status(500).json({
        success: false,
        message: 'Error fetching ride posts',
        error: error.message,
      });
    }
  },

  deleteRidePost: async (req, res) => {
    try {
      const { postId } = req.params;
      
      const ridePost = await RidePost.findByIdAndDelete(postId);
      
      if (!ridePost) {
        return res.status(404).json({
          success: false,
          message: 'Ride post not found',
        });
      }

      res.json({
        success: true,
        message: 'Ride post deleted successfully',
      });
    } catch (error) {
      console.error('Error deleting ride post:', error);
      res.status(500).json({
        success: false,
        message: 'Error deleting ride post',
        error: error.message,
      });
    }
  },

  getUserRides: async (req, res) => {
    try {
      const { userId } = req.params;
      
      // Find rides where user is either the creator or a participant
      const userRides = await RidePost.find({
        $or: [
          { userId: userId },
          { 'participants.userId': userId }
        ]
      }).sort({ createdAt: -1 });

      res.json({
        success: true,
        data: userRides.map(post => ({
          _id: post._id,
          source: post.source,
          destination: post.destination,
          userId: post.userId,
          userName: post.userName,
          gender: post.gender,
          participants: post.participants || [],
          maxParticipants: post.maxParticipants || 3,
          createdAt: post.createdAt,
        })),
      });
    } catch (error) {
      console.error('Error fetching user rides:', error);
      res.status(500).json({
        success: false,
        message: 'Error fetching user rides',
        error: error.message,
      });
    }
  },

  completeRideshareTrip: async (req, res) => {
    try {
      const { postId, userId } = req.body;
      
      if (!postId || !userId) {
        return res.status(400).json({
          success: false,
          message: 'Post ID and User ID are required',
        });
      }

      // Find the ride post
      const ridePost = await RidePost.findById(postId);
      if (!ridePost) {
        return res.status(404).json({
          success: false,
          message: 'Ride post not found',
        });
      }

      // Verify user is part of this ride (creator or participant)
      const isCreator = ridePost.userId.toString() === userId;
      const isParticipant = ridePost.participants?.some(p => p.userId.toString() === userId);
      
      if (!isCreator && !isParticipant) {
        return res.status(403).json({
          success: false,
          message: 'User is not part of this ride',
        });
      }

      // Add 10 gems to user's wallet for completing the rideshare trip
      try {
        await addGemsToUser(userId, 10);
        console.log(`Added 10 gems to user ${userId} for completing rideshare trip`);
      } catch (gemError) {
        console.error(`Error adding gems to user ${userId}:`, gemError);
        // Don't fail the trip completion if gem addition fails
      }

      res.json({
        success: true,
        message: 'Rideshare trip completed successfully and 10 gems added to your wallet!',
        postId: postId,
        userId: userId,
      });
    } catch (error) {
      console.error('Error completing rideshare trip:', error);
      res.status(500).json({
        success: false,
        message: 'Error completing rideshare trip',
        error: error.message,
      });
    }
  },
};

module.exports = rideshareController;
