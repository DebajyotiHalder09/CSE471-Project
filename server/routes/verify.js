const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const {
  submitVerification,
  getAllVerifications,
  getMyVerification,
  approveVerification,
  rejectVerification
} = require('../controllers/verifyController');
const { uploadImage } = require('../controllers/uploadController');

// Upload image (user only)
router.post('/upload-image', authenticateToken, uploadImage);

// Submit verification request (user only)
router.post('/submit', authenticateToken, submitVerification);

// Get my verification status (user only)
router.get('/my-status', authenticateToken, getMyVerification);

// Get all verifications (admin only)
router.get('/all', authenticateToken, getAllVerifications);

// Approve verification (admin only)
router.post('/approve', authenticateToken, approveVerification);

// Reject verification (admin only)
router.post('/reject', authenticateToken, rejectVerification);

module.exports = router;

