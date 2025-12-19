const express = require('express');
const router = express.Router();
const { searchStops, getStopCoordinates } = require('../controllers/stopsController');

// GET /api/stops/search?q=<text> - Prefix search for autocomplete
router.get('/search', searchStops);

// GET /api/stops/coordinates?name=<stop_name> - Get coordinates by exact name
router.get('/coordinates', getStopCoordinates);

module.exports = router;

