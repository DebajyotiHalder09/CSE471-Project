const express = require('express');
const router = express.Router();
const rideshareController = require('../controllers/rideshareController');

router.post('/', rideshareController.createRidePost);
router.get('/', rideshareController.getAllRidePosts);
router.get('/user/:userId', rideshareController.getUserRides);
router.delete('/:postId', rideshareController.deleteRidePost);
router.post('/complete', rideshareController.completeRideshareTrip);

module.exports = router;
