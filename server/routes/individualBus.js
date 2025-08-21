const express = require('express');
const router = express.Router();
const individualBusController = require('../controllers/individualBusController');

router.post('/board', individualBusController.boardBus);
router.post('/end-trip', individualBusController.endTrip);
router.get('/:busId', individualBusController.getIndividualBusById);

module.exports = router;
