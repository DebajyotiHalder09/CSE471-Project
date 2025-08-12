const express = require('express');
const router = express.Router();
const { getAllBuses, searchBusByName, searchBusByRoute } = require('../controllers/busController');

router.get('/all', getAllBuses);

router.get('/search-by-name', searchBusByName);

router.get('/search-by-route', searchBusByRoute);

module.exports = router; 