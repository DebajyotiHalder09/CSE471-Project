const express = require('express');
const router = express.Router();
const reviewController = require('../controllers/reviewController');

router.get('/bus/:busId', reviewController.getReviewsByBusId);
router.post('/', reviewController.createReview);
router.post('/:reviewId/like', reviewController.likeReview);
router.post('/:reviewId/dislike', reviewController.dislikeReview);
router.post('/:reviewId/reply', reviewController.addReply);

module.exports = router;
