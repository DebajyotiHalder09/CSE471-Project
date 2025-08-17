const express = require('express');
const router = express.Router();
const friendsController = require('../controllers/friendsController');
const { authenticateToken } = require('../middleware/auth');

router.get('/', authenticateToken, friendsController.getFriends);
router.post('/add', authenticateToken, friendsController.addFriend);

module.exports = router;
