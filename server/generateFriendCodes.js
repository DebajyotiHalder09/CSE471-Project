const mongoose = require('mongoose');
require('dotenv').config();

const User = require('./models/user');
const Friends = require('./models/friends');

async function generateFriendCodesForExistingUsers() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    const users = await User.find({});
    console.log(`Found ${users.length} users in database`);

    for (const user of users) {
      try {
        const existingFriendCode = await Friends.findOne({ userId: user._id });
        
        if (!existingFriendCode) {
          const friendCode = await Friends.generateUniqueFriendCode();
          const newFriend = new Friends({
            userId: user._id,
            friendCode: friendCode
          });
          await newFriend.save();
          console.log(`Generated friend code ${friendCode} for user: ${user.name} (${user.email})`);
        } else {
          console.log(`User ${user.name} already has friend code: ${existingFriendCode.friendCode}`);
        }
      } catch (error) {
        console.error(`Error processing user ${user.name}:`, error);
      }
    }

    console.log('Friend code generation completed!');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

generateFriendCodesForExistingUsers();
