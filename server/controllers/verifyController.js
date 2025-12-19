const Verify = require('../models/verify');
const User = require('../models/user');

// Submit verification request
const submitVerification = async (req, res) => {
  try {
    const { institutionName, institutionId, gmail, imageUrl } = req.body;
    const userId = req.user._id;

    // Check if user already has a pending or approved verification
    const existingVerify = await Verify.findOne({
      userId: userId,
      status: { $in: ['hold', 'approved'] }
    });

    if (existingVerify) {
      return res.status(400).json({
        success: false,
        message: 'You already have a pending or approved verification request'
      });
    }

    // Get user details
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Create verification request
    const verification = new Verify({
      userId: userId,
      userName: user.name,
      userEmail: user.email,
      institutionName,
      institutionId,
      gmail,
      imageUrl: imageUrl || null,
      status: 'hold'
    });

    await verification.save();

    res.status(201).json({
      success: true,
      message: 'Verification request submitted successfully',
      data: verification
    });
  } catch (error) {
    console.error('Error submitting verification:', error);
    res.status(500).json({
      success: false,
      message: 'Error submitting verification request',
      error: error.message
    });
  }
};

// Get all verification requests (for admin)
const getAllVerifications = async (req, res) => {
  try {
    const verifications = await Verify.find()
      .sort({ createdAt: -1 })
      .populate('userId', 'name email');

    res.status(200).json({
      success: true,
      data: verifications,
      count: verifications.length
    });
  } catch (error) {
    console.error('Error getting verifications:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting verification requests',
      error: error.message
    });
  }
};

// Get verification status for current user
const getMyVerification = async (req, res) => {
  try {
    const userId = req.user._id;
    const verification = await Verify.findOne({ userId: userId })
      .sort({ createdAt: -1 });

    if (!verification) {
      return res.status(200).json({
        success: true,
        data: null,
        message: 'No verification request found'
      });
    }

    res.status(200).json({
      success: true,
      data: verification
    });
  } catch (error) {
    console.error('Error getting verification:', error);
    res.status(500).json({
      success: false,
      message: 'Error getting verification status',
      error: error.message
    });
  }
};

// Approve verification
const approveVerification = async (req, res) => {
  try {
    const { verificationId } = req.body;

    const verification = await Verify.findById(verificationId);
    if (!verification) {
      return res.status(404).json({
        success: false,
        message: 'Verification request not found'
      });
    }

    // Update verification status
    verification.status = 'approved';
    await verification.save();

    // Update user pass to 'student'
    await User.findByIdAndUpdate(verification.userId, {
      pass: 'student'
    });

    res.status(200).json({
      success: true,
      message: 'Verification approved successfully',
      data: verification
    });
  } catch (error) {
    console.error('Error approving verification:', error);
    res.status(500).json({
      success: false,
      message: 'Error approving verification',
      error: error.message
    });
  }
};

// Reject verification
const rejectVerification = async (req, res) => {
  try {
    const { verificationId } = req.body;

    const verification = await Verify.findById(verificationId);
    if (!verification) {
      return res.status(404).json({
        success: false,
        message: 'Verification request not found'
      });
    }

    // Update verification status
    verification.status = 'rejected';
    await verification.save();

    res.status(200).json({
      success: true,
      message: 'Verification rejected',
      data: verification
    });
  } catch (error) {
    console.error('Error rejecting verification:', error);
    res.status(500).json({
      success: false,
      message: 'Error rejecting verification',
      error: error.message
    });
  }
};

module.exports = {
  submitVerification,
  getAllVerifications,
  getMyVerification,
  approveVerification,
  rejectVerification
};

