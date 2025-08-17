const mongoose = require('mongoose');
require('dotenv').config();

const User = require('./models/user');
const Friends = require('./models/friends');

async function addSampleFriends() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    const users = await User.find({});
    console.log(`Found ${users.length} users in database`);

    if (users.length >= 2) {
      const user1 = users[0];
      const user2 = users[1];

      // Get or create Friends documents for both users
      let user1Friends = await Friends.findOne({ userId: user1._id });
      if (!user1Friends) {
        user1Friends = new Friends({
          userId: user1._id,
          friendCode: await Friends.generateUniqueFriendCode(),
          friends: []
        });
      }

      let user2Friends = await Friends.findOne({ userId: user2._id });
      if (!user2Friends) {
        user2Friends = new Friends({
          userId: user2._id,
          friendCode: await Friends.generateUniqueFriendCode(),
          friends: []
        });
      }

      // Add user2 as a friend of user1
      if (!user1Friends.friends.includes(user2._id)) {
        user1Friends.friends.push(user2._id);
        await user1Friends.save();
        console.log(`Added ${user2.name} as friend of ${user1.name}`);
      }

      // Add user1 as a friend of user2
      if (!user2Friends.friends.includes(user1._id)) {
        user2Friends.friends.push(user1._id);
        await user2Friends.save();
        console.log(`Added ${user1.name} as friend of ${user2.name}`);
      }

      console.log('Sample friends added successfully!');
    } else {
      console.log('Need at least 2 users to create sample friends');
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

addSampleFriends();
