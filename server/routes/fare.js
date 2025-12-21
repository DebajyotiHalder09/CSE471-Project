const express = require('express');
const router = express.Router();
const fareController = require('../controllers/fareController');

// Save fare data
router.post('/', fareController.saveFare);

// Get fare for a route
router.get('/', fareController.getFare);

// Get all fares for a user
router.get('/user/:userId', fareController.getUserFares);

module.exports = router;

