const router = require('express').Router();
const {
  getUserOffers,
  updateUserOffers,
  addCashback,
  addCoupon,
  addDiscount,
  useCashback,
  useCoupon,
  useDiscount
} = require('../controllers/offersController');

const verifyToken = require('../middleware/auth');

router.get('/user', verifyToken, getUserOffers);
router.put('/user', verifyToken, updateUserOffers);
router.post('/add-cashback', verifyToken, addCashback);
router.post('/add-coupon', verifyToken, addCoupon);
router.post('/add-discount', verifyToken, addDiscount);
router.post('/use-cashback', verifyToken, useCashback);
router.post('/use-coupon', verifyToken, useCoupon);
router.post('/use-discount', verifyToken, useDiscount);

module.exports = router;
