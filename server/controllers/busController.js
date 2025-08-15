const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

// Since the collection already exists, we'll use it directly
const BusInfo = mongoose.connection.collection('bus_info');
const IndividualBuses = mongoose.connection.collection('buses');

const authenticateToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ 
        success: false, 
        message: 'Access denied. No token provided.' 
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ 
      success: false, 
      message: 'Invalid token.' 
    });
  }
};

const getAllBuses = async (req, res) => {
  try {
    const buses = await BusInfo.find({}).toArray();

    if (buses.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'No buses found' 
      });
    }

    res.status(200).json({
      success: true,
      data: buses,
      count: buses.length
    });

  } catch (error) {
    console.error('Error getting all buses:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

const searchBusByName = async (req, res) => {
  try {
    const { busName } = req.query;
    
    if (!busName) {
      return res.status(400).json({ 
        success: false, 
        message: 'Bus name is required' 
      });
    }

    // Search for buses with name containing the search term (case insensitive)
    const buses = await BusInfo.find({
      busName: { $regex: busName, $options: 'i' }
    }).toArray();

    console.log('Found buses:', buses.length);
    if (buses.length > 0) {
      console.log('First bus data:', JSON.stringify(buses[0], null, 2));
    }

    if (buses.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'No buses found with the given name' 
      });
    }

    res.status(200).json({
      success: true,
      data: buses,
      count: buses.length
    });

  } catch (error) {
    console.error('Error searching bus by name:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

const searchBusByRoute = async (req, res) => {
  try {
    const { startLocation, endLocation } = req.query;
    
    if (!startLocation || !endLocation) {
      return res.status(400).json({ 
        success: false, 
        message: 'Both start and end locations are required' 
      });
    }

    // Search for buses that have both start and end locations in their route
    const buses = await BusInfo.find({
      $and: [
        { 
          'stops.name': { 
            $regex: startLocation, 
            $options: 'i' 
          } 
        },
        { 
          'stops.name': { 
            $regex: endLocation, 
            $options: 'i' 
          } 
        }
      ]
    }).toArray();

    console.log('Found buses for route:', buses.length);
    if (buses.length > 0) {
      console.log('First bus data for route:', JSON.stringify(buses[0], null, 2));
    }

    if (buses.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'No buses found for the specified route' 
      });
    }

    res.status(200).json({
      success: true,
      data: buses,
      count: buses.length
    });

  } catch (error) {
    console.error('Error searching bus by route:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

const getIndividualBuses = async (req, res) => {
  try {
    const { busInfoId } = req.params;
    
    console.log('=== GET INDIVIDUAL BUSES ===');
    console.log('Requested busInfoId:', busInfoId);
    console.log('Requested busInfoId type:', typeof busInfoId);
    
    if (!busInfoId) {
      console.log('No busInfoId provided');
      return res.status(400).json({ 
        success: false, 
        message: 'Bus info ID is required' 
      });
    }

    console.log('Searching for individual buses with parentBusInfoId:', busInfoId);
    console.log('Using collection:', IndividualBuses.collectionName);
    
    // First, let's see what's in the buses collection
    const allBuses = await IndividualBuses.find({}).limit(5).toArray();
    console.log('Sample buses from collection:', allBuses.length);
    if (allBuses.length > 0) {
      console.log('First bus structure:', JSON.stringify(allBuses[0], null, 2));
      console.log('parentBusInfoId field type:', typeof allBuses[0].parentBusInfoId);
      console.log('parentBusInfoId value:', allBuses[0].parentBusInfoId);
      
      // Check all field names in the first document
      console.log('All field names:', Object.keys(allBuses[0]));
    }
    
    // Try different query approaches
    let individualBuses = [];
    
    // Try with ObjectId first
    try {
      individualBuses = await IndividualBuses.find({
        parentBusInfoId: new mongoose.Types.ObjectId(busInfoId)
      }).toArray();
      console.log('Query with ObjectId found:', individualBuses.length, 'buses');
    } catch (objIdError) {
      console.log('ObjectId query failed:', objIdError.message);
    }
    
    // If no results, try with string comparison
    if (individualBuses.length === 0) {
      try {
        individualBuses = await IndividualBuses.find({
          parentBusInfoId: busInfoId
        }).toArray();
        console.log('Query with string found:', individualBuses.length, 'buses');
      } catch (stringError) {
        console.log('String query failed:', stringError.message);
      }
    }
    
    // If still no results, try a broader search
    if (individualBuses.length === 0) {
      try {
        individualBuses = await IndividualBuses.find({
          $or: [
            { parentBusInfoId: busInfoId },
            { parentBusInfoId: new mongoose.Types.ObjectId(busInfoId) }
          ]
        }).toArray();
        console.log('Broad query found:', individualBuses.length, 'buses');
      } catch (broadError) {
        console.log('Broad query failed:', broadError.message);
      }
    }

    console.log('Final result: Found individual buses:', individualBuses.length);
    if (individualBuses.length > 0) {
      console.log('First individual bus:', JSON.stringify(individualBuses[0], null, 2));
    }

    if (individualBuses.length === 0) {
      console.log('No individual buses found');
      return res.status(404).json({ 
        success: false, 
        message: 'No individual buses found for this route' 
      });
    }

    console.log('Returning individual buses successfully');
    res.status(200).json({
      success: true,
      data: individualBuses,
      count: individualBuses.length
    });

  } catch (error) {
    console.error('Error getting individual buses:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

module.exports = {
  authenticateToken,
  getAllBuses,
  searchBusByName,
  searchBusByRoute,
  getIndividualBuses
}; 