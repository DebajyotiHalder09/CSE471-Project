const Fare = require('../models/fare');

const fareController = {
  // Save or update fare data
  saveFare: async (req, res) => {
    try {
      const { userId, source, destination, distance, sourceCoordinates, destinationCoordinates } = req.body;
      
      if (!userId || !source || !destination || distance === undefined) {
        return res.status(400).json({
          success: false,
          message: 'userId, source, destination, and distance are required',
        });
      }

      // Check if fare already exists for this user and route
      const existingFare = await Fare.findOne({
        userId: userId,
        source: source.trim(),
        destination: destination.trim(),
      });

      if (existingFare) {
        // Update existing fare
        existingFare.distance = distance;
        if (sourceCoordinates) existingFare.sourceCoordinates = sourceCoordinates;
        if (destinationCoordinates) existingFare.destinationCoordinates = destinationCoordinates;
        existingFare.createdAt = new Date(); // Reset expiration
        await existingFare.save();

        return res.json({
          success: true,
          message: 'Fare updated successfully',
          data: {
            _id: existingFare._id,
            userId: existingFare.userId,
            source: existingFare.source,
            destination: existingFare.destination,
            distance: existingFare.distance,
            fare: existingFare.distance * 30, // Calculate fare
            sourceCoordinates: existingFare.sourceCoordinates,
            destinationCoordinates: existingFare.destinationCoordinates,
          },
        });
      } else {
        // Create new fare
        const fare = new Fare({
          userId: userId,
          source: source.trim(),
          destination: destination.trim(),
          distance: distance,
          sourceCoordinates: sourceCoordinates || null,
          destinationCoordinates: destinationCoordinates || null,
        });

        await fare.save();

        return res.status(201).json({
          success: true,
          message: 'Fare saved successfully',
          data: {
            _id: fare._id,
            userId: fare.userId,
            source: fare.source,
            destination: fare.destination,
            distance: fare.distance,
            fare: fare.distance * 30, // Calculate fare
            sourceCoordinates: fare.sourceCoordinates,
            destinationCoordinates: fare.destinationCoordinates,
          },
        });
      }
    } catch (error) {
      console.error('Error saving fare:', error);
      res.status(500).json({
        success: false,
        message: 'Error saving fare',
        error: error.message,
      });
    }
  },

  // Get fare for a specific route
  getFare: async (req, res) => {
    try {
      const { userId, source, destination } = req.query;
      
      if (!source || !destination) {
        return res.status(400).json({
          success: false,
          message: 'source and destination are required',
        });
      }

      // First try to find fare for this specific user
      let fare = null;
      if (userId) {
        fare = await Fare.findOne({
          userId: userId,
          source: source.trim(),
          destination: destination.trim(),
        });
      }

      // If not found for user, try to find a general fare (any user with same route)
      if (!fare) {
        fare = await Fare.findOne({
          source: source.trim(),
          destination: destination.trim(),
        }).sort({ createdAt: -1 }); // Get most recent
      }

      if (!fare) {
        return res.status(404).json({
          success: false,
          message: 'Fare not found for this route',
        });
      }

      res.json({
        success: true,
        data: {
          _id: fare._id,
          userId: fare.userId,
          source: fare.source,
          destination: fare.destination,
          distance: fare.distance,
          fare: fare.distance * 30, // Calculate fare
          sourceCoordinates: fare.sourceCoordinates,
          destinationCoordinates: fare.destinationCoordinates,
        },
      });
    } catch (error) {
      console.error('Error getting fare:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting fare',
        error: error.message,
      });
    }
  },

  // Get all fares for a user
  getUserFares: async (req, res) => {
    try {
      const { userId } = req.params;
      
      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'userId is required',
        });
      }

      const fares = await Fare.find({ userId: userId })
        .sort({ createdAt: -1 })
        .limit(50); // Limit to recent 50 fares

      res.json({
        success: true,
        data: fares.map(fare => ({
          _id: fare._id,
          userId: fare.userId,
          source: fare.source,
          destination: fare.destination,
          distance: fare.distance,
          fare: fare.distance * 30,
          sourceCoordinates: fare.sourceCoordinates,
          destinationCoordinates: fare.destinationCoordinates,
          createdAt: fare.createdAt,
        })),
      });
    } catch (error) {
      console.error('Error getting user fares:', error);
      res.status(500).json({
        success: false,
        message: 'Error getting user fares',
        error: error.message,
      });
    }
  },
};

module.exports = fareController;

