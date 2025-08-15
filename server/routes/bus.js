const express = require('express');
const router = express.Router();
const { 
  getAllBuses, 
  searchBusByName, 
  searchBusByRoute, 
  getIndividualBuses,
  authenticateToken 
} = require('../controllers/busController');

router.get('/all', authenticateToken, getAllBuses);

router.get('/search-by-name', authenticateToken, searchBusByName);

router.get('/search-by-route', authenticateToken, searchBusByRoute);

router.get('/individual/:busInfoId', authenticateToken, getIndividualBuses);

module.exports = router; 