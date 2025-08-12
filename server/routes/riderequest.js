const express = require('express');
const router = express.Router();
const {
  sendRideRequest,
  getRideRequests,
  acceptRideRequest,
  rejectRideRequest,
  getUserRequests
} = require('../controllers/riderequestController');

router.post('/send', sendRideRequest);
router.get('/ride/:ridePostId', getRideRequests);
router.put('/accept/:requestId', acceptRideRequest);
router.put('/reject/:requestId', rejectRideRequest);
router.get('/user/:userId', getUserRequests);

module.exports = router;
