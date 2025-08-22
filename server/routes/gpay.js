const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const {
  registerGpay,
  loginGpay,
  getGpayBalance,
  rechargeWallet
} = require('../controllers/gpayController');

router.post('/register', verifyToken, registerGpay);
router.post('/login', verifyToken, loginGpay);
router.get('/balance', verifyToken, getGpayBalance);
router.post('/recharge', verifyToken, rechargeWallet);

module.exports = router;
