// filepath: D:\Codes\Flutter\bus_app\server\routes\auth.js
const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const User = require('../models/user');

// Middleware to verify JWT token
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
    console.log('User ID type:', typeof decoded.id);
    
    // Check if we're connected to the right database
    console.log('Current database:', mongoose.connection.db?.databaseName);
    console.log('User collection:', User.collection.name);
    
    const user = await User.findById(decoded.id).select('-password');
    console.log('Found user:', user ? 'Yes' : 'No');
    if (user) {
      console.log('User details:', {
        id: user._id,
        name: user.name,
        email: user.email
      });
    }
    
    if (!user) {
      console.log('User not found in database');
      return res.status(401).json({ error: 'Invalid token.' });
    }

    req.user = user;
    console.log('Token verification successful');
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    console.error('Error name:', error.name);
    console.error('Error message:', error.message);
    res.status(401).json({ error: 'Invalid token.' });
  }
};

// Signup Route
router.post('/signup', async (req, res) => {
  try {
    const { name, email, gender, role, password } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const user = new User({
      name,
      email,
      gender,
      role,
      password: hashedPassword,
    });

    await user.save();
    res.status(200).json({ message: 'User created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Login Route
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'User not found' });
    }

    // Check password
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid password' });
    }

    // Create token
    console.log('Creating JWT token for user ID:', user._id);
    console.log('User object for JWT:', {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gender: user.gender,
    });
    
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);
    console.log('JWT token created successfully');
    
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

// Validate token route
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

// Get current user route
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

// Debug route to check database connection and users
router.get('/debug/users', async (req, res) => {
  try {
    console.log('=== DEBUG: Checking database connection ===');
    
    // Check connection state
    console.log('MongoDB connection state:', mongoose.connection.readyState);
    console.log('Current database:', mongoose.connection.db?.databaseName);
    
    // Try to count users
    const userCount = await User.countDocuments();
    console.log('Total users in database:', userCount);
    
    // Try to find sample users
    const sampleUsers = await User.find().limit(3).select('-password');
    console.log('Sample users:', sampleUsers);
    
    // Check collection details
    const collectionName = User.collection.name;
    const dbName = User.db.name;
    console.log('Collection name:', collectionName);
    console.log('Database name:', dbName);
    
    res.json({
      message: 'Database connection working',
      connectionState: mongoose.connection.readyState,
      currentDatabase: mongoose.connection.db?.databaseName,
      collectionName: collectionName,
      databaseName: dbName,
      userCount: userCount,
      sampleUsers: sampleUsers
    });
  } catch (error) {
    console.error('Debug route error:', error);
    res.status(500).json({ 
      error: error.message,
      connectionState: mongoose.connection.readyState,
      currentDatabase: mongoose.connection.db?.databaseName
    });
  }
});

// Simple test route to check if server is reachable
router.get('/test', (req, res) => {
  res.json({ message: 'Auth server is working!' });
});

// Test route to check database connection and collection
router.get('/test-db', async (req, res) => {
  try {
    console.log('=== TESTING DATABASE CONNECTION ===');
    
    // Check if we're connected
    if (mongoose.connection.readyState !== 1) {
      return res.status(500).json({ 
        error: 'Not connected to MongoDB',
        state: mongoose.connection.readyState 
      });
    }
    
    // Get database info
    const dbName = mongoose.connection.db.databaseName;
    console.log('Current database:', dbName);
    
    // List all collections
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Available collections:', collections.map(c => c.name));
    
    // Check if 'users' collection exists
    const usersCollectionExists = collections.some(c => c.name === 'users');
    console.log('Users collection exists:', usersCollectionExists);
    
    // Try to count users
    let userCount = 0;
    if (usersCollectionExists) {
      userCount = await User.countDocuments();
      console.log('Total users in collection:', userCount);
      
      // Try to find one user to see the structure
      if (userCount > 0) {
        const sampleUser = await User.findOne().select('-password');
        console.log('Sample user structure:', {
          _id: sampleUser._id,
          _idType: typeof sampleUser._id,
          _idString: sampleUser._id.toString(),
          name: sampleUser.name,
          email: sampleUser.email
        });
      }
    }
    
    res.json({
      message: 'Database test completed',
      database: dbName,
      collections: collections.map(c => c.name),
      usersCollectionExists: usersCollectionExists,
      userCount: userCount,
      connectionState: mongoose.connection.readyState,
      sampleUser: userCount > 0 ? {
        id: (await User.findOne().select('-password'))._id.toString(),
        name: (await User.findOne().select('-password')).name
      } : null
    });
    
  } catch (error) {
    console.error('Database test error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Test route to find users
router.get('/find-users', async (req, res) => {
  try {
    console.log('=== FINDING USERS ===');
    console.log('Database:', mongoose.connection.db?.databaseName);
    console.log('Collection:', User.collection.name);
    
    const users = await User.find().select('-password').limit(5);
    console.log('Found users:', users.length);
    
    if (users.length > 0) {
      console.log('First user ID:', users[0]._id);
      console.log('First user name:', users[0].name);
      console.log('First user ID type:', typeof users[0]._id);
      console.log('First user ID toString:', users[0]._id.toString());
    }
    
    res.json({
      message: 'Users found',
      count: users.length,
      users: users
    });
  } catch (error) {
    console.error('Error finding users:', error);
    res.status(500).json({ error: error.message });
  }
});

// Test route to check JWT token
router.get('/test-token', async (req, res) => {
  try {
    console.log('=== TESTING JWT TOKEN ===');
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.json({ error: 'No token provided' });
    }
    
    console.log('Token received:', token.substring(0, 20) + '...');
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('Token decoded:', decoded);
    
    // Try to find user with this ID
    const user = await User.findById(decoded.id);
    console.log('User found:', user ? 'Yes' : 'No');
    
    res.json({
      message: 'Token test completed',
      tokenValid: true,
      userId: decoded.id,
      userFound: !!user,
      database: mongoose.connection.db?.databaseName,
      collection: User.collection.name
    });
    
  } catch (error) {
    console.error('Token test error:', error);
    res.json({ 
      error: error.message,
      tokenValid: false
    });
  }
});

// Test route to check database connection and collection
router.get('/test-db', async (req, res) => {
  try {
    console.log('=== TESTING DATABASE CONNECTION ===');
    
    // Check if we're connected
    if (mongoose.connection.readyState !== 1) {
      return res.status(500).json({ 
        error: 'Not connected to MongoDB',
        state: mongoose.connection.readyState 
      });
    }
    
    // Get database info
    const dbName = mongoose.connection.db.databaseName;
    console.log('Current database:', dbName);
    
    // List all collections
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Available collections:', collections.map(c => c.name));
    
    // Check if 'users' collection exists
    const usersCollectionExists = collections.some(c => c.name === 'users');
    console.log('Users collection exists:', usersCollectionExists);
    
    // Try to count users
    let userCount = 0;
    if (usersCollectionExists) {
      userCount = await User.countDocuments();
      console.log('Total users in collection:', userCount);
      
      // Try to find one user to see the structure
      if (userCount > 0) {
        const sampleUser = await User.findOne().select('-password');
        console.log('Sample user structure:', {
          _id: sampleUser._id,
          _idType: typeof sampleUser._id,
          _idString: sampleUser._id.toString(),
          name: sampleUser.name,
          email: sampleUser.email
        });
      }
    }
    
    res.json({
      message: 'Database test completed',
      database: dbName,
      collections: collections.map(c => c.name),
      usersCollectionExists: usersCollectionExists,
      userCount: userCount,
      connectionState: mongoose.connection.readyState,
      sampleUser: userCount > 0 ? {
        id: (await User.findOne().select('-password'))._id.toString(),
        name: (await User.findOne().select('-password')).name
      } : null
    });
    
  } catch (error) {
    console.error('Database test error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update profile route
router.put('/profile', verifyToken, async (req, res) => {
  try {
    console.log('=== PROFILE UPDATE REQUEST ===');
    console.log('Request body:', req.body);
    console.log('Current user from token:', req.user);
    console.log('User ID to update:', req.user._id);
    console.log('User ID type:', typeof req.user._id);
    console.log('User ID value:', req.user._id);
    
    // Check if we're connected to the right database
    console.log('Current database:', mongoose.connection.db?.databaseName);
    console.log('User model collection:', User.collection.name);
    
    const updateData = {};
    
    // Only update fields that are provided and have valid values
    if (req.body.name !== undefined && req.body.name !== null && req.body.name.trim() !== '') {
      updateData.name = req.body.name.trim();
      console.log('Adding name to update:', updateData.name);
    }
    
    if (req.body.email !== undefined && req.body.email !== null && req.body.email.trim() !== '') {
      updateData.email = req.body.email.trim();
      console.log('Adding email to update:', updateData.email);
      
      // Check if email is already taken by another user
      if (req.body.email !== req.user.email) {
        const existingUser = await User.findOne({ email: req.body.email });
        if (existingUser) {
          return res.status(400).json({ error: 'Email already exists' });
        }
      }
    }
    
    if (req.body.gender !== undefined && req.body.gender !== null && req.body.gender !== '') {
      updateData.gender = req.body.gender;
      console.log('Adding gender to update:', updateData.gender);
    }

    console.log('Final update data:', updateData);
    console.log('Number of fields to update:', Object.keys(updateData).length);

    // Only update if there are fields to update
    if (Object.keys(updateData).length === 0) {
      console.log('No fields to update, returning error');
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    // Verify user still exists before updating
    console.log('Verifying user exists with ID:', req.user._id);
    console.log('Searching in collection:', User.collection.name);
    
    const existingUser = await User.findById(req.user._id);
    if (!existingUser) {
      console.log('User not found in database');
      console.log('Trying to find any users in collection...');
      const allUsers = await User.find().limit(1);
      console.log('Any users found:', allUsers.length);
      if (allUsers.length > 0) {
        console.log('Sample user ID format:', allUsers[0]._id);
        console.log('Sample user ID type:', typeof allUsers[0]._id);
      }
      return res.status(404).json({ error: 'User not found' });
    }
    console.log('User found in database:', existingUser);

    // Update user profile
    console.log('Attempting to update user with ID:', req.user._id);
    console.log('Update data to send:', updateData);
    
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      updateData,
      { new: true, runValidators: false }
    ).select('-password');

    if (!updatedUser) {
      console.log('Update operation failed - no user returned');
      return res.status(500).json({ error: 'Failed to update user profile' });
    }

    console.log('Profile updated successfully:', updatedUser);
    console.log('=== PROFILE UPDATE SUCCESS ===');

    res.json({
      message: 'Profile updated successfully',
      user: updatedUser
    });
  } catch (error) {
    console.error('=== PROFILE UPDATE ERROR ===');
    console.error('Error details:', error);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Error name:', error.name);
    
    // Check if it's a MongoDB connection error
    if (error.name === 'MongoNetworkError') {
      console.error('MongoDB network error detected');
    }
    
    res.status(500).json({ error: error.message });
  }
});

// Update password route
router.put('/password', verifyToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // Get user with password
    const user = await User.findById(req.user._id);
    
    // Verify current password
    const validPassword = await bcrypt.compare(currentPassword, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    
    // Update password
    await User.findByIdAndUpdate(req.user._id, { password: hashedPassword });

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update profile route
router.put('/profile', verifyToken, async (req, res) => {
  try {
    console.log('=== PROFILE UPDATE REQUEST ===');
    console.log('Request body:', req.body);
    console.log('Current user from token:', req.user);
    console.log('User ID to update:', req.user._id);
    console.log('User ID type:', typeof req.user._id);
    console.log('User ID value:', req.user._id);
    
    // Check if we're connected to the right database
    console.log('Current database:', mongoose.connection.db?.databaseName);
    console.log('User model collection:', User.collection.name);
    
    const updateData = {};
    
    // Only update fields that are provided and have valid values
    if (req.body.name !== undefined && req.body.name !== null && req.body.name.trim() !== '') {
      updateData.name = req.body.name.trim();
      console.log('Adding name to update:', updateData.name);
    }
    
    if (req.body.email !== undefined && req.body.email !== null && req.body.email.trim() !== '') {
      updateData.email = req.body.email.trim();
      console.log('Adding email to update:', updateData.email);
      
      // Check if email is already taken by another user
      if (req.body.email !== req.user.email) {
        const existingUser = await User.findOne({ email: req.body.email });
        if (existingUser) {
          return res.status(400).json({ error: 'Email already exists' });
        }
      }
    }
    
    if (req.body.gender !== undefined && req.body.gender !== null && req.body.gender !== '') {
      updateData.gender = req.body.gender;
      console.log('Adding gender to update:', updateData.gender);
    }

    console.log('Final update data:', updateData);
    console.log('Number of fields to update:', Object.keys(updateData).length);

    // Only update if there are fields to update
    if (Object.keys(updateData).length === 0) {
      console.log('No fields to update, returning error');
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    // Verify user still exists before updating
    console.log('Verifying user exists with ID:', req.user._id);
    console.log('Searching in collection:', User.collection.name);
    
    const existingUser = await User.findById(req.user._id);
    if (!existingUser) {
      console.log('User not found in database');
      console.log('Trying to find any users in collection...');
      const allUsers = await User.find().limit(1);
      console.log('Any users found:', allUsers.length);
      if (allUsers.length > 0) {
        console.log('Sample user ID format:', allUsers[0]._id);
        console.log('Sample user ID type:', typeof allUsers[0]._id);
      }
      return res.status(404).json({ error: 'User not found' });
    }
    console.log('User found in database:', existingUser);

    // Update user profile
    console.log('Attempting to update user with ID:', req.user._id);
    console.log('Update data to send:', updateData);
    
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      updateData,
      { new: true, runValidators: false }
    ).select('-password');

    if (!updatedUser) {
      console.log('Update operation failed - no user returned');
      return res.status(500).json({ error: 'Failed to update user profile' });
    }

    console.log('Profile updated successfully:', updatedUser);
    console.log('=== PROFILE UPDATE SUCCESS ===');

    res.json({
      message: 'Profile updated successfully',
      user: updatedUser
    });
  } catch (error) {
    console.error('=== PROFILE UPDATE ERROR ===');
    console.error('Error details:', error);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Error name:', error.name);
    
    // Check if it's a MongoDB connection error
    if (error.name === 'MongoNetworkError') {
      console.error('MongoDB network error detected');
    }
    
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;