const express = require('express');
const router = express.Router();
const { searchBusByName, searchBusByRoute } = require('../controllers/busController');

// Route to search bus by name
router.get('/search-by-name', searchBusByName);

// Route to search bus by route
router.get('/search-by-route', searchBusByRoute);

module.exports = router; 