const express = require('express');
const router = express.Router();
const individualBusController = require('../controllers/individualBusController');

router.post('/board', individualBusController.boardBus);
router.post('/end-trip', individualBusController.endTrip);

module.exports = router;
