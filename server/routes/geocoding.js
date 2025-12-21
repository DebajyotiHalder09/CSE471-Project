const express = require('express');
const router = express.Router();
const geocodingController = require('../controllers/geocodingController');

// Health check
router.get('/health', geocodingController.health);

// Search for addresses (returns suggestions)
router.get('/search', geocodingController.search);

// Geocode a single address (returns coordinates)
router.get('/geocode', geocodingController.geocode);

// Calculate road distance between two coordinates
router.get('/distance', geocodingController.calculateDistance);

module.exports = router;

