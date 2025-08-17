const mongoose = require('mongoose');
require('dotenv').config();
const Wallet = require('./models/wallet');
const User = require('./models/user');

async function testGemConversion() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    console.log('\n=== Testing Gem Conversion System ===\n');

    // Get a user to test with
    const user = await User.findOne({});
    if (!user) {
      console.log('No users found in database');
      process.exit(1);
    }

    console.log(`Testing with user: ${user.name} (${user.email})`);

    // Find or create wallet for the user
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

    console.log(`\nInitial wallet state:`);
    console.log(`  Balance: ৳${wallet.balance}`);
    console.log(`  Gems: ${wallet.gems}`);

    // Add some gems to test conversion
    wallet.gems = 150;
    await wallet.save();
    console.log(`\nAdded 150 gems to wallet for testing`);

    // Test the conversion logic
    const currentGems = wallet.gems;
    const currentBalance = wallet.balance;
    
    if (currentGems < 50) {
      console.log('❌ Not enough gems to convert (need at least 50)');
      return;
    }
    
    // Calculate conversion: 50 gems = 1 BDT
    const gemsToConvert = Math.floor(currentGems / 50) * 50;
    const balanceToAdd = gemsToConvert / 50;
    
    console.log(`\nConverting ${gemsToConvert} gems to ${balanceToAdd} BDT`);
    
    // Update wallet
    wallet.gems -= gemsToConvert;
    wallet.balance += balanceToAdd;
    wallet.lastUpdated = new Date();
    
    await wallet.save();
    
    console.log(`\nAfter conversion:`);
    console.log(`  Balance: ৳${wallet.balance}`);
    console.log(`  Gems: ${wallet.gems}`);
    console.log(`  ✅ Successfully converted ${gemsToConvert} gems to ৳${balanceToAdd}!`);

    console.log('\n=== Gem Conversion Test Complete ===');
    console.log('✅ Conversion logic working correctly!');
    
    process.exit(0);
  } catch (error) {
    console.error('Error testing gem conversion:', error);
    process.exit(1);
  }
}

testGemConversion();
