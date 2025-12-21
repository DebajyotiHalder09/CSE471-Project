const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/ratingController');

// Get rating for a specific bus
router.get('/bus/:busId', ratingController.getBusRating);

// Get all bus ratings
router.get('/all', ratingController.getAllBusRatings);

// Submit a rating
router.post('/', ratingController.submitRating);

module.exports = router;

