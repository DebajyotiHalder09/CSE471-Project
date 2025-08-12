const RideRequest = require('../models/riderequest');
const RidePost = require('../models/rideshare');

const sendRideRequest = async (req, res) => {
  try {
    const { ridePostId, requesterId, requesterName, requesterGender } = req.body;

    if (!ridePostId || !requesterId || !requesterName || !requesterGender) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }

    const ridePost = await RidePost.findById(ridePostId);
    if (!ridePost) {
      return res.status(404).json({
        success: false,
        message: 'Ride post not found'
      });
    }

    if (ridePost.userId === requesterId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot send request to your own ride post'
      });
    }

    const currentParticipants = ridePost.participants ? ridePost.participants.length : 0;
    if (currentParticipants >= ridePost.maxParticipants) {
      return res.status(400).json({
        success: false,
        message: 'Ride is already full'
      });
    }

    const existingRequest = await RideRequest.findOne({
      ridePostId,
      requesterId,
      status: { $in: ['pending', 'accepted'] }
    });

    if (existingRequest) {
      return res.status(400).json({
        success: false,
        message: 'You already have a pending or accepted request for this ride'
      });
    }

    const rideRequest = new RideRequest({
      ridePostId,
      requesterId,
      requesterName,
      requesterGender
    });

    await rideRequest.save();

    res.status(201).json({
      success: true,
      message: 'Ride request sent successfully',
      data: rideRequest
    });
  } catch (error) {
    console.error('Error sending ride request:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send ride request'
    });
  }
};

const getRideRequests = async (req, res) => {
  try {
    const { ridePostId } = req.params;

    const requests = await RideRequest.find({ ridePostId }).sort({ createdAt: -1 });

    res.json({
      success: true,
      data: requests
    });
  } catch (error) {
    console.error('Error getting ride requests:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get ride requests'
    });
  }
};

const acceptRideRequest = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { ridePostId } = req.body;

    const rideRequest = await RideRequest.findById(requestId);
    if (!rideRequest) {
      return res.status(404).json({
        success: false,
        message: 'Ride request not found'
      });
    }

    if (rideRequest.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: 'Request is not pending'
      });
    }

    const ridePost = await RidePost.findById(ridePostId);
    if (!ridePost) {
      return res.status(404).json({
        success: false,
        message: 'Ride post not found'
      });
    }

    const currentParticipants = ridePost.participants ? ridePost.participants.length : 0;
    if (currentParticipants >= ridePost.maxParticipants) {
      return res.status(400).json({
        success: false,
        message: 'Ride is already full'
      });
    }

    rideRequest.status = 'accepted';
    await rideRequest.save();

    if (!ridePost.participants) {
      ridePost.participants = [];
    }

    ridePost.participants.push({
      userId: rideRequest.requesterId,
      userName: rideRequest.requesterName,
      gender: rideRequest.requesterGender,
      joinedAt: new Date()
    });

    await ridePost.save();

    res.json({
      success: true,
      message: 'Ride request accepted successfully',
      data: rideRequest
    });
  } catch (error) {
    console.error('Error accepting ride request:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to accept ride request'
    });
  }
};

const rejectRideRequest = async (req, res) => {
  try {
    const { requestId } = req.params;

    const rideRequest = await RideRequest.findById(requestId);
    if (!rideRequest) {
      return res.status(404).json({
        success: false,
        message: 'Ride request not found'
      });
    }

    if (rideRequest.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: 'Request is not pending'
      });
    }

    rideRequest.status = 'rejected';
    await rideRequest.save();

    res.json({
      success: true,
      message: 'Ride request rejected successfully',
      data: rideRequest
    });
  } catch (error) {
    console.error('Error rejecting ride request:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to reject ride request'
    });
  }
};

const getUserRequests = async (req, res) => {
  try {
    const { userId } = req.params;

    const requests = await RideRequest.find({ requesterId: userId }).sort({ createdAt: -1 });

    res.json({
      success: true,
      data: requests
    });
  } catch (error) {
    console.error('Error getting user requests:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user requests'
    });
  }
};

module.exports = {
  sendRideRequest,
  getRideRequests,
  acceptRideRequest,
  rejectRideRequest,
  getUserRequests
};
