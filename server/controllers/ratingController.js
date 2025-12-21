const Rating = require('../models/rating');
const BusInfo = require('../models/busInfo');
const mongoose = require('mongoose');

const ratingController = {
  // Get rating for a specific bus
  getBusRating: async (req, res) => {
    try {
      const { busId } = req.params;
      
      let rating = await Rating.findOne({ busId: busId });
      
      // If no rating exists, create one with random rating
      if (!rating) {
        const randomRating = (Math.random() * 2 + 3).toFixed(1); // Random between 3.0 and 5.0
        rating = new Rating({
          busId: busId,
          averageRating: parseFloat(randomRating),
          totalRatings: Math.floor(Math.random() * 50) + 10, // Random between 10-60
          ratings: []
        });
        await rating.save();
      }
      
      res.json({
        success: true,
        data: {
          busId: rating.busId,
          averageRating: rating.averageRating,
          totalRatings: rating.totalRatings,
        },
      });
    } catch (error) {
      console.error('Error getting bus rating:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting bus rating',
        error: error.message,
      });
    }
  },

  // Get all bus ratings
  getAllBusRatings: async (req, res) => {
    try {
      // Use native MongoDB driver to match bus controller
      const BusInfoCollection = mongoose.connection.collection('bus_info');
      const RatingCollection = mongoose.connection.collection('ratings');
      
      // Get all buses from bus_info collection
      const allBuses = await BusInfoCollection.find({}).toArray();
      
      // Get all existing ratings
      const existingRatings = await RatingCollection.find({}).toArray();
      
      const ratingMap = {};
      
      // Map existing ratings by busId (convert ObjectId to string)
      existingRatings.forEach(rating => {
        const busId = rating.busId;
        const busIdStr = busId instanceof mongoose.Types.ObjectId 
          ? busId.toString() 
          : String(busId);
        ratingMap[busIdStr] = {
          averageRating: rating.averageRating || 0,
          totalRatings: rating.totalRatings || 0,
        };
      });
      
      // Create ratings for buses that don't have one
      const busesWithoutRatings = allBuses.filter(bus => {
        const busIdStr = bus._id instanceof mongoose.Types.ObjectId 
          ? bus._id.toString() 
          : String(bus._id);
        return !ratingMap[busIdStr];
      });
      
      for (const bus of busesWithoutRatings) {
        const busId = bus._id;
        const busIdStr = busId instanceof mongoose.Types.ObjectId 
          ? busId.toString() 
          : String(busId);
        
        // Generate random rating between 3.0 and 5.0
        const randomRating = parseFloat((Math.random() * 2 + 3).toFixed(1));
        const randomTotalRatings = Math.floor(Math.random() * 50) + 10; // Random between 10-60
        
        // Create rating document using Mongoose model for proper schema validation
        const newRating = new Rating({
          busId: busId,
          averageRating: randomRating,
          totalRatings: randomTotalRatings,
          ratings: []
        });
        await newRating.save();
        
        ratingMap[busIdStr] = {
          averageRating: randomRating,
          totalRatings: randomTotalRatings,
        };
      }
      
      console.log('Returning ratings for', Object.keys(ratingMap).length, 'buses');
      console.log('Sample bus IDs in ratings:', Object.keys(ratingMap).slice(0, 3));
      
      res.json({
        success: true,
        data: ratingMap,
      });
    } catch (error) {
      console.error('Error getting all bus ratings:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting all bus ratings',
        error: error.message,
      });
    }
  },

  // Submit a rating for a bus
  submitRating: async (req, res) => {
    try {
      const { busId, userId, rating, comment } = req.body;
      
      if (!busId || !userId || !rating || rating < 1 || rating > 5) {
        return res.status(400).json({
          success: false,
          message: 'busId, userId, and rating (1-5) are required',
        });
      }

      let busRating = await Rating.findOne({ busId: busId });
      
      if (!busRating) {
        busRating = new Rating({
          busId: busId,
          averageRating: rating,
          totalRatings: 1,
          ratings: []
        });
      }
      
      // Check if user already rated this bus
      const existingRatingIndex = busRating.ratings.findIndex(
        r => r.userId.toString() === userId
      );
      
      if (existingRatingIndex !== -1) {
        // Update existing rating
        busRating.ratings[existingRatingIndex].rating = rating;
        busRating.ratings[existingRatingIndex].comment = comment || '';
        busRating.ratings[existingRatingIndex].createdAt = new Date();
      } else {
        // Add new rating
        busRating.ratings.push({
          userId: userId,
          rating: rating,
          comment: comment || '',
          createdAt: new Date()
        });
      }
      
      // Recalculate average
      busRating.calculateAverageRating();
      await busRating.save();
      
      res.json({
        success: true,
        data: {
          busId: busRating.busId,
          averageRating: busRating.averageRating,
          totalRatings: busRating.totalRatings,
        },
      });
    } catch (error) {
      console.error('Error submitting rating:', error);
      res.status(500).json({
        success: false,
        message: 'Error submitting rating',
        error: error.message,
      });
    }
  },
};

module.exports = ratingController;

