const IndividualBus = require('../models/individualBus');
const jwt = require('jsonwebtoken');

const boardBus = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { busId } = req.body;

    if (!busId) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required field: busId' 
      });
    }

    const bus = await IndividualBus.findById(busId);
    if (!bus) {
      return res.status(404).json({ 
        success: false, 
        message: 'Bus not found' 
      });
    }

    if (bus.currentPassengerCount >= bus.totalPassengerCapacity) {
      return res.status(400).json({ 
        success: false, 
        message: 'Bus is at full capacity' 
      });
    }

    bus.currentPassengerCount += 1;
    await bus.save();

    res.status(200).json({
      success: true,
      message: 'Successfully boarded bus',
      data: bus
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    
    console.error('Error boarding bus:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const endTrip = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { busId } = req.body;

    if (!busId) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required field: busId' 
      });
    }

    const bus = await IndividualBus.findById(busId);
    if (!bus) {
      return res.status(404).json({ 
        success: false, 
        message: 'Bus not found' 
      });
    }

    if (bus.currentPassengerCount <= 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'No passengers to remove' 
      });
    }

    bus.currentPassengerCount -= 1;
    await bus.save();

    res.status(200).json({
      success: true,
      message: 'Successfully ended trip',
      data: bus
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    
    console.error('Error ending trip:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = {
  boardBus,
  endTrip
};
