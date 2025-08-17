const mongoose = require('mongoose');
require('dotenv').config();

const Wallet = require('./models/wallet');

async function updateWalletsWithGems() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URL);
    console.log('Connected to MongoDB successfully!');

    console.log('Updating existing wallets to include gems field...');
    
    const result = await Wallet.updateMany(
      { gems: { $exists: false } },
      { $set: { gems: 0 } }
    );

    console.log(`Updated ${result.modifiedCount} wallets with gems field`);
    
    // Verify the update
    const totalWallets = await Wallet.countDocuments();
    const walletsWithGems = await Wallet.countDocuments({ gems: { $exists: true } });
    
    console.log(`Total wallets: ${totalWallets}`);
    console.log(`Wallets with gems field: ${walletsWithGems}`);
    
    if (totalWallets === walletsWithGems) {
      console.log('✅ All wallets now have the gems field!');
    } else {
      console.log('⚠️ Some wallets still missing gems field');
    }

    process.exit(0);
  } catch (error) {
    console.error('Error updating wallets:', error);
    process.exit(1);
  }
}

updateWalletsWithGems();
