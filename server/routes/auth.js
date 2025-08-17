const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

// Import all models to ensure they are registered
const User = require('../models/user');
const FriendRequest = require('../models/friendRequest');
const Friends = require('../models/friends');
const Wallet = require('../models/wallet');

const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    console.log('=== TOKEN VERIFICATION ===');
    console.log('Authorization header:', req.headers.authorization);
    console.log('Extracted token:', token ? `${token.substring(0, 20)}...` : 'No token');
    
    if (!token) {
      console.log('No token provided');
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('JWT decoded successfully:', decoded);
    console.log('Looking for user with ID:', decoded.id);
    
    const user = await User.findById(decoded.id).select('-password');
    console.log('Found user:', user ? 'Yes' : 'No');
    
    if (!user) {
      console.log('User not found in database');
      return res.status(401).json({ error: 'Invalid token.' });
    }

    req.user = user;
    console.log('Token verification successful for user:', user.name);
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ error: 'Invalid token.' });
  }
};

router.post('/signup', async (req, res) => {
  try {
    const { name, email, gender, role, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({
      name,
      email,
      gender,
      role,
      password: hashedPassword,
    });

    await user.save();
    
    try {
      const newWallet = new Wallet({
        userId: user._id,
        balance: 0,
        currency: 'BDT',
        lastUpdated: new Date()
      });
      await newWallet.save();
    } catch (walletError) {
      console.error('Error creating wallet for new user:', walletError);
    }
    
    try {
      const friendCode = await Friends.generateUniqueFriendCode();
      const newFriend = new Friends({
        userId: user._id,
        friendCode: friendCode
      });
      await newFriend.save();
      console.log(`Friend code created automatically for new user: ${user.name} (${friendCode})`);
    } catch (friendError) {
      console.error('Error creating friend code for new user:', friendError);
    }
    
    res.status(200).json({ message: 'User created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'User not found' });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid password' });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);
    
    res.json({
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        gender: user.gender,
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/validate', verifyToken, (req, res) => {
  res.json({
    valid: true,
    user: {
      id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      role: req.user.role,
    }
  });
});

router.get('/me', verifyToken, (req, res) => {
  res.json({
    user: {
      id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      role: req.user.role,
      gender: req.user.gender,
    }
  });
});

router.put('/profile', verifyToken, async (req, res) => {
  try {
    const updateData = {};
    
    if (req.body.name !== undefined && req.body.name !== null && req.body.name.trim() !== '') {
      updateData.name = req.body.name.trim();
    }
    
    if (req.body.email !== undefined && req.body.email !== null && req.body.email.trim() !== '') {
      updateData.email = req.body.email.trim();
      
      if (req.body.email !== req.user.email) {
        const existingUser = await User.findOne({ email: req.body.email });
        if (existingUser) {
          return res.status(400).json({ error: 'Email already exists' });
        }
      }
    }
    
    if (req.body.gender !== undefined && req.body.gender !== null && req.body.gender !== '') {
      updateData.gender = req.body.gender;
    }

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    const existingUser = await User.findById(req.user._id);
    if (!existingUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      updateData,
      { new: true, runValidators: false }
    ).select('-password');

    if (!updatedUser) {
      return res.status(500).json({ error: 'Failed to update user profile' });
    }

    res.json({
      message: 'Profile updated successfully',
      user: updatedUser
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.put('/password', verifyToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    const user = await User.findById(req.user._id);
    const validPassword = await bcrypt.compare(currentPassword, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Current password is incorrect' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await User.findByIdAndUpdate(req.user._id, { password: hashedPassword });

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/user/:userId', verifyToken, async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('=== SEARCH USER BY ID ===');
    console.log('Searching for user ID:', userId);
    console.log('Request user:', req.user);
    
    if (!userId || userId.trim() === '') {
      console.log('User ID is empty or invalid');
      return res.status(400).json({ error: 'User ID is required' });
    }

    console.log('Looking up user in database...');
    const user = await User.findById(userId).select('-password');
    console.log('Database lookup result:', user);
    
    if (!user) {
      console.log('User not found in database');
      return res.status(404).json({ error: 'User not found' });
    }

    const responseData = {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gender: user.gender,
    };
    
    console.log('Sending response:', responseData);
    res.json(responseData);
  } catch (error) {
    console.error('Error in search user route:', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user ID format' });
    }
    res.status(500).json({ error: error.message });
  }
});

router.get('/friend-code', verifyToken, async (req, res) => {
      try {
      console.log('=== GET FRIEND CODE ===');
      console.log('Request user:', req.user);
      
      const friendRecord = await Friends.findOne({ userId: req.user._id });
      
      if (!friendRecord) {
        console.log('Friend code not found for user');
        return res.status(404).json({ error: 'Friend code not found' });
      }
      
      console.log('Friend code found:', friendRecord.friendCode);
      res.json({ friendCode: friendRecord.friendCode });
    } catch (error) {
      console.error('Error getting friend code:', error);
      res.status(500).json({ error: error.message });
    }
});

router.get('/search-friend/:friendCode', verifyToken, async (req, res) => {
  try {
    const { friendCode } = req.params;
    console.log('=== SEARCH FRIEND BY CODE ===');
    console.log('Searching for friend code:', friendCode);
    console.log('Request user:', req.user);
    
    if (!friendCode || friendCode.trim() === '') {
      console.log('Friend code is empty or invalid');
      return res.status(400).json({ error: 'Friend code is required' });
    }

    if (friendCode.length !== 5) {
      console.log('Friend code must be exactly 5 characters');
      return res.status(400).json({ error: 'Friend code must be exactly 5 characters' });
    }

    console.log('Looking up friend in database...');
    const friendRecord = await Friends.findOne({ friendCode: friendCode.toUpperCase() });
    
    if (!friendRecord) {
      console.log('Friend not found in database');
      return res.status(404).json({ error: 'Friend not found' });
    }

    const user = await User.findById(friendRecord.userId).select('-password');
    if (!user) {
      console.log('User not found for friend code');
      return res.status(404).json({ error: 'User not found' });
    }

    const responseData = {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gender: user.gender,
      friendCode: friendRecord.friendCode
    };
    
    console.log('Sending response:', responseData);
    res.json(responseData);
  } catch (error) {
    console.error('Error in search friend route:', error);
    res.status(500).json({ error: error.message });
  }
});

// Send friend request
router.post('/send-friend-request', verifyToken, async (req, res) => {
  try {
    console.log('=== SEND FRIEND REQUEST ===');
    const { toUserId } = req.body;
    const fromUserId = req.user._id;
    
    console.log('Request body:', req.body);
    console.log('From user ID:', fromUserId);
    console.log('To user ID:', toUserId);

    if (!toUserId) {
      return res.status(400).json({ error: 'Recipient user ID is required' });
    }

    if (fromUserId.toString() === toUserId) {
      return res.status(400).json({ error: 'Cannot send friend request to yourself' });
    }

    // Check if request already exists
    const existingRequest = await FriendRequest.findOne({
      $or: [
        { fromUserId, toUserId },
        { fromUserId: toUserId, toUserId: fromUserId }
      ]
    });

    console.log('Existing request check:', existingRequest);

    if (existingRequest) {
      if (existingRequest.status === 'pending') {
        return res.status(400).json({ error: 'Friend request already pending' });
      } else if (existingRequest.status === 'accepted') {
        return res.status(400).json({ error: 'Already friends' });
      }
    }

    // Create new friend request
    const friendRequest = new FriendRequest({
      fromUserId,
      toUserId,
      status: 'pending'
    });

    await friendRequest.save();
    console.log(`Friend request saved successfully with ID: ${friendRequest._id}`);
    console.log(`Friend request sent from ${req.user.name} to user ${toUserId}`);

    res.json({ message: 'Friend request sent successfully' });
  } catch (error) {
    console.error('Error sending friend request:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get pending friend requests for current user
router.get('/pending-friend-requests', verifyToken, async (req, res) => {
  try {
    console.log('=== GET PENDING FRIEND REQUESTS ===');
    console.log('Current user ID:', req.user._id);
    
    const pendingRequests = await FriendRequest.find({
      toUserId: req.user._id,
      status: 'pending'
    }).populate('fromUserId', 'name email');

    console.log('Found pending requests:', pendingRequests.length);
    console.log('Pending requests:', pendingRequests);

    res.json({ requests: pendingRequests });
  } catch (error) {
    console.error('Error getting pending friend requests:', error);
    res.status(500).json({ error: error.message });
  }
});

// Accept friend request
router.put('/accept-friend-request/:requestId', verifyToken, async (req, res) => {
  try {
    const { requestId } = req.params;
    const friendRequest = await FriendRequest.findById(requestId);

    if (!friendRequest) {
      return res.status(404).json({ error: 'Friend request not found' });
    }

    if (friendRequest.toUserId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Not authorized to accept this request' });
    }

    if (friendRequest.status !== 'pending') {
      return res.status(400).json({ error: 'Request is not pending' });
    }

    // Update request status
    friendRequest.status = 'accepted';
    await friendRequest.save();

    // Add to friends list for both users
    
    // Add to sender's friends list
    await Friends.findOneAndUpdate(
      { userId: friendRequest.fromUserId },
      { $addToSet: { friends: friendRequest.toUserId } }
    );

    // Add to recipient's friends list
    await Friends.findOneAndUpdate(
      { userId: friendRequest.toUserId },
      { $addToSet: { friends: friendRequest.fromUserId } }
    );

    console.log(`Friend request accepted between users ${friendRequest.fromUserId} and ${friendRequest.toUserId}`);

    res.json({ message: 'Friend request accepted successfully' });
  } catch (error) {
    console.error('Error accepting friend request:', error);
    res.status(500).json({ error: error.message });
  }
});

// Reject friend request
router.put('/reject-friend-request/:requestId', verifyToken, async (req, res) => {
  try {
    const { requestId } = req.params;
    const friendRequest = await FriendRequest.findById(requestId);

    if (!friendRequest) {
      return res.status(404).json({ error: 'Friend request not found' });
    }

    if (friendRequest.toUserId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Not authorized to reject this request' });
    }

    if (friendRequest.status !== 'pending') {
      return res.status(400).json({ error: 'Request is not pending' });
    }

    friendRequest.status = 'rejected';
    await friendRequest.save();

    console.log(`Friend request rejected by user ${req.user.name}`);

    res.json({ message: 'Friend request rejected successfully' });
  } catch (error) {
    console.error('Error rejecting friend request:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get current user's friends list
router.get('/friends', verifyToken, async (req, res) => {
  try {
    const userFriends = await Friends.findOne({ userId: req.user._id }).populate('friends', 'name email');

    if (!userFriends) {
      return res.json({ friends: [] });
    }

    res.json({ friends: userFriends.friends });
  } catch (error) {
    console.error('Error getting friends list:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
