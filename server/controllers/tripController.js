const Trip = require('../models/trip');
const jwt = require('jsonwebtoken');
const { addGemsToUser } = require('./walletController');

const addTrip = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

    const { busId, busName, distance, fare, source, destination } = req.body;

    if (!busId || !busName || distance === undefined || fare === undefined || !source || !destination) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields: busId, busName, distance, fare, source, destination' 
      });
    }

    const newTrip = new Trip({
      userId,
      busId,
      busName,
      distance,
      fare,
      source,
      destination
    });

    await newTrip.save();

    // Add 10 gems to user's wallet for completing the trip
    try {
      await addGemsToUser(userId, 10);
      console.log(`Added 10 gems to user ${userId} for completing trip`);
    } catch (gemError) {
      console.error(`Error adding gems to user ${userId}:`, gemError);
      // Don't fail the trip completion if gem addition fails
    }

    res.status(201).json({
      success: true,
      message: 'Trip recorded successfully and 10 gems added to your wallet!',
      data: newTrip
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    
    console.error('Error adding trip:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const getUserTrips = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id;

    const trips = await Trip.find({ userId })
      .sort({ createdAt: -1 })
      .limit(100);

    res.status(200).json({
      success: true,
      message: 'Trips fetched successfully',
      data: trips
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    
    console.error('Error fetching user trips:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = {
  addTrip,
  getUserTrips
};
