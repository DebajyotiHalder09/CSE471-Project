const Stop = require('../models/stops');

/**
 * Optimized search stops by prefix
 * GET /api/stops/search?q=<text>
 * 
 * Optimizations:
 * - Uses regex prefix (^) for index utilization
 * - Forces index usage with hint()
 * - Uses lean() for faster queries
 * - Sorts for consistent results
 * - Early return for empty queries
 */
const searchStops = async (req, res) => {
  try {
    const query = req.query.q;

    // Early return for empty query - fastest path
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(200).json({
        success: true,
        data: [],
      });
    }

    // Convert query to lowercase for prefix search
    const searchTerm = query.trim().toLowerCase();

    // Optimized query with index hint for maximum performance
    // Using regex with ^ prefix ensures index usage
    // hint() forces MongoDB to use the search index
    // sort() ensures consistent ordering
    // lean() returns plain JS objects (faster than Mongoose documents)
    // limit() early to reduce data transfer
    const stops = await Stop.find({
      search: { $regex: `^${searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}` }, // Escape regex special chars
    })
      .hint({ search: 1 }) // Force index usage
      .select('name lat lng -_id') // Return name, lat, lng fields, exclude _id
      .sort({ search: 1 }) // Sort by search field for consistent results
      .limit(10) // Limit early
      .lean() // Use lean() for better performance (no Mongoose overhead)
      .allowDiskUse(false); // Force in-memory operations

    // Return stops with coordinates (lean() already returns plain objects)
    const stopsData = stops.map(stop => ({
      name: stop.name,
      lat: stop.lat,
      lng: stop.lng,
    }));

    res.status(200).json({
      success: true,
      data: stopsData,
    });
  } catch (error) {
    console.error('Error searching stops:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Get stop coordinates by exact name match
 * GET /api/stops/coordinates?name=<stop_name>
 * Fast lookup for coordinates when processing search results
 */
const getStopCoordinates = async (req, res) => {
  try {
    const name = req.query.name;

    // Handle empty query safely
    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(200).json({
        success: true,
        data: null,
      });
    }

    // Convert to lowercase for search field lookup
    const searchTerm = name.trim().toLowerCase();

    // Fast exact match lookup using index
    const stop = await Stop.findOne({
      search: searchTerm,
    })
      .select('name lat lng -_id')
      .lean();

    if (stop) {
      res.status(200).json({
        success: true,
        data: {
          name: stop.name,
          lat: stop.lat,
          lng: stop.lng,
        },
      });
    } else {
      res.status(200).json({
        success: true,
        data: null,
      });
    }
  } catch (error) {
    console.error('Error getting stop coordinates:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

module.exports = {
  searchStops,
  getStopCoordinates,
};

