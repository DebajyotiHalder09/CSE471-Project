const mongoose = require('mongoose');

// Since the collection already exists, we'll use it directly
const BusInfo = mongoose.connection.collection('bus_info');

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
          stops: { 
            $regex: startLocation, 
            $options: 'i' 
          } 
        },
        { 
          stops: { 
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

module.exports = {
  searchBusByName,
  searchBusByRoute
}; 