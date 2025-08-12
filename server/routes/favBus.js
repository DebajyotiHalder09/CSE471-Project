const express = require('express');
const router = express.Router();
const {
  addToFavorites,
  removeFromFavorites,
  getUserFavorites,
  checkIfFavorited
} = require('../controllers/favBusController');

router.post('/add', addToFavorites);
router.delete('/remove', removeFromFavorites);
router.get('/user/:userId', getUserFavorites);
router.get('/check', checkIfFavorited);

module.exports = router;
