const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const {
  registerGpay,
  loginGpay,
  getGpayBalance
} = require('../controllers/gpayController');

router.post('/register', verifyToken, registerGpay);
router.post('/login', verifyToken, loginGpay);
router.get('/balance', verifyToken, getGpayBalance);

module.exports = router;
