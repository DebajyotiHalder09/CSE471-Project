const express = require('express');
const router = express.Router();
const { addTrip, getUserTrips } = require('../controllers/tripController');
const authenticateToken = require('../middleware/auth');

router.post('/add', authenticateToken, addTrip);
router.get('/user', authenticateToken, getUserTrips);

module.exports = router;
