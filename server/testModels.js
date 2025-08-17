const mongoose = require('mongoose');
require('dotenv').config();

async function testModels() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    // Test User model
    console.log('\n=== Testing User Model ===');
    const User = require('./models/user');
    console.log('User model collection name:', User.collection.name);
    
    const userCount = await User.countDocuments();
    console.log('Total users in database:', userCount);

    // Test Friends model
    console.log('\n=== Testing Friends Model ===');
    const Friends = require('./models/friends');
    console.log('Friends model collection name:', Friends.collection.name);
    
    const friendsCount = await Friends.countDocuments();
    console.log('Total friends documents in database:', friendsCount);

    // Test FriendRequest model
    console.log('\n=== Testing FriendRequest Model ===');
    const FriendRequest = require('./models/friendRequest');
    console.log('FriendRequest model collection name:', FriendRequest.collection.name);
    
    const requestCount = await FriendRequest.countDocuments();
    console.log('Total friend requests in database:', requestCount);

    // Test population
    console.log('\n=== Testing Population ===');
    if (friendsCount > 0) {
      const sampleFriend = await Friends.findOne().populate('userId', 'name email');
      console.log('Sample friend with populated user:', sampleFriend);
    }

    console.log('\nAll models are working correctly!');
    process.exit(0);
  } catch (error) {
    console.error('Error testing models:', error);
    process.exit(1);
  }
}

testModels();
