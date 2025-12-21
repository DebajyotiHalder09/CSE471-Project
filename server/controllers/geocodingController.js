const axios = require('axios');

// Rate limiting: 1 request per second (Nominatim's limit)
let lastRequestTime = 0;
const MIN_REQUEST_INTERVAL = 1000; // 1 second in milliseconds

// Helper function to calculate road distance using OSRM
const calculateRoadDistance = async (srcLat, srcLon, dstLat, dstLon) => {
  try {
    // OSRM format: /route/v1/driving/{lon},{lat};{lon},{lat}
    const osrmUrl = `http://router.project-osrm.org/route/v1/driving/${srcLon},${srcLat};${dstLon},${dstLat}?overview=false`;
    
    const routeResponse = await axios.get(osrmUrl, {
      timeout: 15000 // 15 second timeout
    });

    if (routeResponse.data && routeResponse.data.code === 'Ok' && routeResponse.data.routes && routeResponse.data.routes.length > 0) {
      // Distance is in meters, convert to km
      const distanceInMeters = routeResponse.data.routes[0].distance;
      const distanceInKm = distanceInMeters / 1000;
      const roundedDistance = Math.round(distanceInKm * 10) / 10;
      
      return {
        success: true,
        distance: roundedDistance
      };
    } else {
      // Fallback to Haversine if OSRM fails
      return calculateHaversineDistance(srcLat, srcLon, dstLat, dstLon);
    }
  } catch (osrmError) {
    console.warn('OSRM API error, falling back to Haversine distance:', osrmError.message);
    // Fallback to Haversine if OSRM is unavailable
    return calculateHaversineDistance(srcLat, srcLon, dstLat, dstLon);
  }
};

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
  const roundedDistance = Math.round(distance * 10) / 10;
  
  return {
    success: true,
    distance: roundedDistance
  };
};

// Helper function to enforce rate limiting
const rateLimitedRequest = async (requestFn) => {
  const now = Date.now();
  const timeSinceLastRequest = now - lastRequestTime;
  
  if (timeSinceLastRequest < MIN_REQUEST_INTERVAL) {
    const waitTime = MIN_REQUEST_INTERVAL - timeSinceLastRequest;
    await new Promise(resolve => setTimeout(resolve, waitTime));
  }
  
  lastRequestTime = Date.now();
  return requestFn();
};

const geocodingController = {
  // Health check endpoint
  health: async (req, res) => {
    res.json({
      success: true,
      message: 'Geocoding service is running',
      timestamp: new Date().toISOString(),
    });
  },

  // Search for addresses (returns suggestions with detailed info)
  search: async (req, res) => {
    try {
      const { q, limit = 5, countrycodes = 'bd' } = req.query;
      
      if (!q || q.trim() === '') {
        return res.status(400).json({
          success: false,
          message: 'Query parameter "q" is required',
        });
      }

      const results = await rateLimitedRequest(async () => {
        try {
          // Try multiple strategies
          const strategies = [
            { q: `${q}, Dhaka, Bangladesh`, countrycodes: 'bd' },
            { q: q, countrycodes: 'bd' },
            { q: `${q}, Dhaka, Bangladesh` },
            { q: q },
          ];

          for (const params of strategies) {
            try {
              const response = await axios.get('https://nominatim.openstreetmap.org/search', {
                params: {
                  ...params,
                  format: 'json',
                  limit: parseInt(limit),
                  addressdetails: 1,
                },
                headers: {
                  'User-Agent': 'SmartCommute-Dhaka/1.0 (geocoding-service)',
                },
                timeout: 10000,
              });

              if (response.data && response.data.length > 0) {
                // Filter results to prefer Bangladesh locations
                const bangladeshResults = response.data.filter(result => {
                  const address = result.address || {};
                  const country = address.country || '';
                  return country.toLowerCase().includes('bangladesh') || 
                         country.toLowerCase().includes('bd');
                });

                if (bangladeshResults.length > 0) {
                  return bangladeshResults.slice(0, parseInt(limit));
                }

                // If no Bangladesh results, return all results
                return response.data.slice(0, parseInt(limit));
              }
            } catch (error) {
              console.warn(`Geocoding strategy failed: ${error.message}`);
              continue;
            }
          }

          return [];
        } catch (error) {
          console.error('Geocoding error:', error.message);
          throw error;
        }
      });

      // Format results with detailed address information
      const formattedResults = results.map(result => ({
        display_name: result.display_name || '',
        lat: parseFloat(result.lat) || 0,
        lon: parseFloat(result.lon) || 0,
        address: result.address || {},
        boundingbox: result.boundingbox || [],
        place_id: result.place_id || null,
        type: result.type || '',
        importance: result.importance || 0,
      }));

      res.json({
        success: true,
        data: formattedResults,
      });
    } catch (error) {
      console.error('Error in geocoding search:', error);
      res.status(500).json({
        success: false,
        message: 'Error searching for addresses',
        error: error.message,
      });
    }
  },

  // Geocode a single address (returns coordinates)
  geocode: async (req, res) => {
    try {
      const { q } = req.query;
      
      if (!q || q.trim() === '') {
        return res.status(400).json({
          success: false,
          message: 'Query parameter "q" is required',
        });
      }

      const result = await rateLimitedRequest(async () => {
        try {
          // Try multiple strategies
          const strategies = [
            { q: `${q}, Dhaka, Bangladesh`, countrycodes: 'bd' },
            { q: q, countrycodes: 'bd' },
            { q: `${q}, Dhaka, Bangladesh` },
            { q: q },
          ];

          for (const params of strategies) {
            try {
              const response = await axios.get('https://nominatim.openstreetmap.org/search', {
                params: {
                  ...params,
                  format: 'json',
                  limit: 1,
                  addressdetails: 1,
                },
                headers: {
                  'User-Agent': 'SmartCommute-Dhaka/1.0 (geocoding-service)',
                },
                timeout: 10000,
              });

              if (response.data && response.data.length > 0) {
                // Prefer Bangladesh results
                const bangladeshResult = response.data.find(result => {
                  const address = result.address || {};
                  const country = address.country || '';
                  return country.toLowerCase().includes('bangladesh') || 
                         country.toLowerCase().includes('bd');
                });

                return bangladeshResult || response.data[0];
              }
            } catch (error) {
              console.warn(`Geocoding strategy failed: ${error.message}`);
              continue;
            }
          }

          return null;
        } catch (error) {
          console.error('Geocoding error:', error.message);
          throw error;
        }
      });

      if (!result) {
        return res.status(404).json({
          success: false,
          message: 'Address not found',
        });
      }

      // Return detailed result
      res.json({
        success: true,
        data: {
          display_name: result.display_name || '',
          lat: parseFloat(result.lat) || 0,
          lon: parseFloat(result.lon) || 0,
          address: result.address || {},
          boundingbox: result.boundingbox || [],
          place_id: result.place_id || null,
          type: result.type || '',
          importance: result.importance || 0,
        },
      });
    } catch (error) {
      console.error('Error in geocoding:', error);
      res.status(500).json({
        success: false,
        message: 'Error geocoding address',
        error: error.message,
      });
    }
  },

  // Calculate road distance between two coordinates
  calculateDistance: async (req, res) => {
    try {
      const { sourceLat, sourceLon, destLat, destLon } = req.query;
      
      if (!sourceLat || !sourceLon || !destLat || !destLon) {
        return res.status(400).json({
          success: false,
          message: 'sourceLat, sourceLon, destLat, and destLon are required',
        });
      }

      const srcLat = parseFloat(sourceLat);
      const srcLon = parseFloat(sourceLon);
      const dstLat = parseFloat(destLat);
      const dstLon = parseFloat(destLon);

      if (isNaN(srcLat) || isNaN(srcLon) || isNaN(dstLat) || isNaN(dstLon)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinates',
        });
      }

      const result = await calculateRoadDistance(srcLat, srcLon, dstLat, dstLon);

      res.json({
        success: true,
        data: {
          distance: result.distance,
          fare: result.distance * 30, // Calculate fare: 30 BDT per km
        },
      });
    } catch (error) {
      console.error('Error calculating distance:', error);
      res.status(500).json({
        success: false,
        message: 'Error calculating distance',
        error: error.message,
      });
    }
  },
};

module.exports = geocodingController;

