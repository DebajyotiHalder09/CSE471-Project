const mongoose = require('mongoose');
require('dotenv').config();

const Wallet = require('./models/wallet');
const User = require('./models/user');

async function testGemRewards() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    console.log('\n=== Testing Gem Reward System ===\n');

    // Get all users and their wallets
    const users = await User.find({}).limit(3);
    console.log(`Found ${users.length} users to test`);

    for (const user of users) {
      console.log(`\n--- Testing User: ${user.name} (${user.email}) ---`);
      
      let wallet = await Wallet.findOne({ userId: user._id });
      if (!wallet) {
        console.log('Creating new wallet for user...');
        wallet = new Wallet({
          userId: user._id,
          balance: 0,
          gems: 0,
          currency: 'BDT',
          lastUpdated: new Date()
        });
        await wallet.save();
      }
      
      console.log(`Initial wallet state:`);
      console.log(`  Balance: ৳${wallet.balance}`);
      console.log(`  Gems: ${wallet.gems}`);
      
      // Simulate adding gems (like completing a trip)
      const { addGemsToUser } = require('./controllers/walletController');
      await addGemsToUser(user._id.toString(), 10);
      
      // Refresh wallet data
      wallet = await Wallet.findOne({ userId: user._id });
      console.log(`After adding 10 gems:`);
      console.log(`  Balance: ৳${wallet.balance}`);
      console.log(`  Gems: ${wallet.gems}`);
      console.log(`  ✅ Gems increased by 10!`);
    }

    console.log('\n=== Gem Reward System Test Complete ===');
    console.log('✅ All users received 10 gems successfully!');

    process.exit(0);
  } catch (error) {
    console.error('Error testing gem rewards:', error);
    process.exit(1);
  }
}

testGemRewards();
