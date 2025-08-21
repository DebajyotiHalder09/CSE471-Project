const express = require('express');
const router = express.Router();
const { getWalletBalance, testWallet, debugWallets, initializeAllUserWallets, convertGemsToBalance, deductFromWallet } = require('../controllers/walletController');
const { authenticateToken } = require('../middleware/auth');

router.get('/test', authenticateToken, testWallet);
router.get('/debug', authenticateToken, debugWallets);
router.get('/balance', authenticateToken, getWalletBalance);
router.post('/initialize-all', authenticateToken, initializeAllUserWallets);
router.post('/convert-gems', authenticateToken, convertGemsToBalance);
router.post('/deduct', authenticateToken, deductFromWallet);

module.exports = router;
