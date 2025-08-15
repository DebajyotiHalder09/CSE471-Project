const express = require('express');
const router = express.Router();
const { addTrip, getUserTrips } = require('../controllers/tripController');

router.post('/add', addTrip);
router.get('/user', getUserTrips);

module.exports = router;
