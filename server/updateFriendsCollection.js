const mongoose = require('mongoose');
require('dotenv').config();

const Friends = require('./models/friends');

async function updateFriendsCollection() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    // Update all existing friends documents to include empty friends array
    const result = await Friends.updateMany(
      { friends: { $exists: false } },
      { $set: { friends: [] } }
    );

    console.log(`Updated ${result.modifiedCount} friends documents`);

    // Verify the update
    const allFriends = await Friends.find({});
    console.log(`Total friends documents: ${allFriends.length}`);
    
    for (const friend of allFriends) {
      console.log(`User ${friend.userId} has ${friend.friends.length} friends`);
    }

    console.log('Friends collection update completed!');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

updateFriendsCollection();
