const RidePost = require('../models/rideshare');
const Fare = require('../models/fare');
const { addGemsToUser } = require('./walletController');
const axios = require('axios');

// Helper function to calculate Haversine (straight-line) distance as fallback
const calculateHaversineDistance = (srcLat, srcLon, dstLat, dstLon) => {
  const R = 6371; // Earth's radius in km
  const dLat = (dstLat - srcLat) * Math.PI / 180;
  const dLon = (dstLon - srcLon) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(srcLat * Math.PI / 180) * Math.cos(dstLat * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  // Round to 1 decimal place
  const roundedDistance = Math.round(distance * 10) / 10;
  // Calculate fare: 30 BDT per km
  const fare = roundedDistance * 30.0;

  return {
    distance: roundedDistance,
    fare: fare
  };
};

// Helper function to calculate distance and fare using geocoding and road distance
const calculateFare = async (source, destination) => {
  try {
    console.log(`Calculating fare for: ${source} -> ${destination}`);
    
    // Geocode source
    const sourceResponse = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: {
        q: source,
        format: 'json',
        limit: 1,
        addressdetails: 1
      },
      headers: {
        'User-Agent': 'BusApp/1.0'
      },
      timeout: 10000 // 10 second timeout
    });

    // Geocode destination
    const destResponse = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: {
        q: destination,
        format: 'json',
        limit: 1,
        addressdetails: 1
      },
      headers: {
        'User-Agent': 'BusApp/1.0'
      },
      timeout: 10000 // 10 second timeout
    });

    if (!sourceResponse.data || sourceResponse.data.length === 0) {
      console.error('Source geocoding failed for:', source);
      throw new Error('Could not find source location');
    }

    if (!destResponse.data || destResponse.data.length === 0) {
      console.error('Destination geocoding failed for:', destination);
      throw new Error('Could not find destination location');
    }

    const srcLat = parseFloat(sourceResponse.data[0].lat);
    const srcLon = parseFloat(sourceResponse.data[0].lon);
    const dstLat = parseFloat(destResponse.data[0].lat);
    const dstLon = parseFloat(destResponse.data[0].lon);

    console.log(`Geocoded coordinates: (${srcLat}, ${srcLon}) -> (${dstLat}, ${dstLon})`);

    // Calculate road distance using OSRM (Open Source Routing Machine)
    // OSRM format: /route/v1/driving/{lon},{lat};{lon},{lat}
    try {
      const osrmUrl = `http://router.project-osrm.org/route/v1/driving/${srcLon},${srcLat};${dstLon},${dstLat}?overview=false`;
      console.log(`Requesting road distance from OSRM...`);
      
      const routeResponse = await axios.get(osrmUrl, {
        timeout: 15000 // 15 second timeout
      });

      if (routeResponse.data && routeResponse.data.code === 'Ok' && routeResponse.data.routes && routeResponse.data.routes.length > 0) {
        // Distance is in meters, convert to km
        const distanceInMeters = routeResponse.data.routes[0].distance;
        const distanceInKm = distanceInMeters / 1000;
        const roundedDistance = Math.round(distanceInKm * 10) / 10;
        
        // Calculate fare: 30 BDT per km
        const fare = roundedDistance * 30.0;

        console.log(`OSRM road distance: ${roundedDistance}km, Fare: ৳${fare.toFixed(0)}`);

        return {
          distance: roundedDistance,
          fare: fare
        };
      } else {
        console.warn('OSRM route not found, falling back to Haversine distance');
        // Fallback to Haversine if OSRM fails
        return calculateHaversineDistance(srcLat, srcLon, dstLat, dstLon);
      }
    } catch (osrmError) {
      console.warn('OSRM API error, falling back to Haversine distance:', osrmError.message);
      // Fallback to Haversine if OSRM is unavailable
      return calculateHaversineDistance(srcLat, srcLon, dstLat, dstLon);
    }
  } catch (error) {
    console.error('Error calculating fare:', error.message);
    // Return default values on error
    return {
      distance: 10.0,
      fare: 300.0
    };
  }
};

const rideshareController = {
  createRidePost: async (req, res) => {
    try {
      const { source, destination, userId, userName, gender, maxParticipants } = req.body;
      
      if (!source || !destination || !userId || !userName || !gender) {
        return res.status(400).json({
          success: false,
          message: 'All fields are required',
        });
      }

      // Validate maxParticipants (2-9)
      const participantLimit = maxParticipants && maxParticipants >= 2 && maxParticipants <= 9 
        ? maxParticipants 
        : 3; // Default to 3 if invalid

      // First, try to get cached fare from database
      let fareData = null;
      try {
        const cachedFare = await Fare.findOne({
          userId: userId,
          source: source.trim(),
          destination: destination.trim(),
        });

        if (!cachedFare) {
          // Try to find general fare (any user with same route)
          const generalFare = await Fare.findOne({
            source: source.trim(),
            destination: destination.trim(),
          }).sort({ createdAt: -1 });

          if (generalFare) {
            fareData = {
              distance: generalFare.distance,
              fare: generalFare.distance * 30.0
            };
          }
        } else {
          fareData = {
            distance: cachedFare.distance,
            fare: cachedFare.distance * 30.0
          };
        }
      } catch (fareError) {
        console.warn('Error getting cached fare:', fareError.message);
      }

      // If no cached fare found, calculate using geocoding and OSRM
      if (!fareData) {
        fareData = await calculateFare(source, destination);
        
        // Save the calculated fare to database for future use
        try {
          const srcResponse = await axios.get('https://nominatim.openstreetmap.org/search', {
            params: { q: source, format: 'json', limit: 1, addressdetails: 1 },
            headers: { 'User-Agent': 'BusApp/1.0' },
            timeout: 10000
          });
          const dstResponse = await axios.get('https://nominatim.openstreetmap.org/search', {
            params: { q: destination, format: 'json', limit: 1, addressdetails: 1 },
            headers: { 'User-Agent': 'BusApp/1.0' },
            timeout: 10000
          });

          if (srcResponse.data && srcResponse.data.length > 0 && 
              dstResponse.data && dstResponse.data.length > 0) {
            const srcLat = parseFloat(srcResponse.data[0].lat);
            const srcLon = parseFloat(srcResponse.data[0].lon);
            const dstLat = parseFloat(dstResponse.data[0].lat);
            const dstLon = parseFloat(dstResponse.data[0].lon);

            await Fare.findOneAndUpdate(
              { userId: userId, source: source.trim(), destination: destination.trim() },
              {
                userId: userId,
                source: source.trim(),
                destination: destination.trim(),
                distance: fareData.distance,
                sourceCoordinates: { lat: srcLat, lon: srcLon },
                destinationCoordinates: { lat: dstLat, lon: dstLon },
                createdAt: new Date()
              },
              { upsert: true, new: true }
            );
          }
        } catch (saveError) {
          console.warn('Error saving fare to database:', saveError.message);
        }
      }

      const ridePost = new RidePost({
        source,
        destination,
        userId,
        userName,
        gender,
        maxParticipants: participantLimit,
        distance: fareData.distance,
        fare: fareData.fare,
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
          maxParticipants: ridePost.maxParticipants,
          participants: ridePost.participants || [],
          distance: ridePost.distance,
          fare: ridePost.fare,
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
          distance: post.distance,
          fare: post.fare,
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
          distance: post.distance,
          fare: post.fare,
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
