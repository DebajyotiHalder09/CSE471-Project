const Wallet = require('../models/wallet');
const User = require('../models/user');

const getWalletBalance = async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('Getting wallet balance for user ID:', userId);
    console.log('User ID type:', typeof userId);
    console.log('Full user object:', req.user);
    
    let wallet = await Wallet.findOne({ userId });
    console.log('Found wallet:', wallet);
    
    if (!wallet) {
      console.log('Creating new wallet for user:', userId);
      wallet = new Wallet({
        userId: userId,
        balance: 0,
        gems: 0,
        currency: 'BDT',
        lastUpdated: new Date()
      });
      await wallet.save();
      console.log('New wallet created with balance:', wallet.balance);
    }
    
    console.log('Returning wallet balance:', wallet.balance);
    res.status(200).json({
      success: true,
      balance: wallet.balance,
      gems: wallet.gems,
      currency: wallet.currency,
      lastUpdated: wallet.lastUpdated,
      message: 'Wallet balance retrieved successfully'
    });
  } catch (error) {
    console.error('Error in getWalletBalance:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving wallet balance',
      error: error.message
    });
  }
};

const initializeAllUserWallets = async (req, res) => {
  try {
    console.log('Initializing wallets for all existing users...');
    
    const allUsers = await User.find({});
    console.log(`Found ${allUsers.length} users in the system`);
    
    let createdCount = 0;
    let existingCount = 0;
    
    for (const user of allUsers) {
      const existingWallet = await Wallet.findOne({ userId: user._id });
      
      if (!existingWallet) {
        const newWallet = new Wallet({
          userId: user._id,
          balance: 0,
          currency: 'BDT',
          lastUpdated: new Date()
        });
        await newWallet.save();
        console.log(`Created wallet for user: ${user.name} (${user._id})`);
        createdCount++;
      } else {
        console.log(`Wallet already exists for user: ${user.name} (${user._id})`);
        existingCount++;
      }
    }
    
    console.log(`Wallet initialization complete. Created: ${createdCount}, Existing: ${existingCount}`);
    
    res.status(200).json({
      success: true,
      message: 'All user wallets initialized successfully',
      totalUsers: allUsers.length,
      walletsCreated: createdCount,
      walletsExisting: existingCount
    });
  } catch (error) {
    console.error('Error in initializeAllUserWallets:', error);
    res.status(500).json({
      success: false,
      message: 'Error initializing user wallets',
      error: error.message
    });
  }
};

const createWalletForNewUser = async (userId) => {
  try {
    console.log(`Creating wallet for new user: ${userId}`);
    
    const existingWallet = await Wallet.findOne({ userId });
    if (existingWallet) {
      console.log(`Wallet already exists for user: ${userId}`);
      return existingWallet;
    }
    
    const newWallet = new Wallet({
      userId: userId,
      balance: 0,
      gems: 0,
      currency: 'BDT',
      lastUpdated: new Date()
    });
    
    await newWallet.save();
    console.log(`Wallet created successfully for user: ${userId}`);
    return newWallet;
  } catch (error) {
    console.error(`Error creating wallet for user ${userId}:`, error);
    throw error;
  }
};

const addGemsToUser = async (userId, gemAmount = 10) => {
  try {
    console.log(`Adding ${gemAmount} gems to user: ${userId}`);
    
    let wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      console.log(`Creating new wallet for user: ${userId}`);
      wallet = new Wallet({
        userId: userId,
        balance: 0,
        gems: gemAmount,
        currency: 'BDT',
        lastUpdated: new Date()
      });
    } else {
      wallet.gems += gemAmount;
      wallet.lastUpdated = new Date();
    }
    
    await wallet.save();
    console.log(`Successfully added ${gemAmount} gems to user ${userId}. New gem count: ${wallet.gems}`);
    return wallet;
  } catch (error) {
    console.error(`Error adding gems to user ${userId}:`, error);
    throw error;
  }
};

const convertGemsToBalance = async (req, res) => {
  try {
    const userId = req.user.id;
    console.log(`Converting gems to balance for user ID: ${userId}`);
    
    let wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'Wallet not found'
      });
    }
    
    const currentGems = wallet.gems;
    const currentBalance = wallet.balance;
    
    console.log(`Current gems: ${currentGems}, Current balance: ${currentBalance}`);
    
    if (currentGems < 50) {
      return res.status(400).json({
        success: false,
        message: 'You need at least 50 gems to convert to balance'
      });
    }
    
    // Calculate conversion: 50 gems = 1 BDT
    const gemsToConvert = Math.floor(currentGems / 50) * 50;
    const balanceToAdd = gemsToConvert / 50;
    
    console.log(`Converting ${gemsToConvert} gems to ${balanceToAdd} BDT`);
    
    // Update wallet
    wallet.gems -= gemsToConvert;
    wallet.balance += balanceToAdd;
    wallet.lastUpdated = new Date();
    
    await wallet.save();
    
    console.log(`Successfully converted ${gemsToConvert} gems to ${balanceToAdd} BDT`);
    console.log(`New gems: ${wallet.gems}, New balance: ${wallet.balance}`);
    
    res.status(200).json({
      success: true,
      message: `Successfully converted ${gemsToConvert} gems to ৳${balanceToAdd}`,
      balance: wallet.balance,
      gems: wallet.gems,
      convertedAmount: balanceToAdd,
      gemsUsed: gemsToConvert
    });
    
  } catch (error) {
    console.error('Error converting gems to balance:', error);
    res.status(500).json({
      success: false,
      message: 'Error converting gems to balance',
      error: error.message
    });
  }
};

const testWallet = async (req, res) => {
  try {
    console.log('Testing wallet API...');
    console.log('Request headers:', req.headers);
    console.log('Request user:', req.user);
    
    res.status(200).json({
      success: true,
      message: 'Wallet API test successful',
      user: req.user,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Error in testWallet:', error);
    res.status(500).json({
      success: false,
      message: 'Error in wallet test',
      error: error.message
    });
  }
};

const debugWallets = async (req, res) => {
  try {
    console.log('Debugging wallets collection...');
    const allWallets = await Wallet.find({});
    console.log('All wallets found:', allWallets);
    
    const allUsers = await User.find({});
    console.log('All users found:', allUsers);
    
    // Test finding wallet by the exact user ID from your data
    const testUserId = '689a3fd97983d592a8d74eef';
    const testWallet = await Wallet.findOne({ userId: testUserId });
    console.log('Test wallet for user 689a3fd97983d592a8d74eef:', testWallet);
    
    res.status(200).json({
      success: true,
      message: 'Wallet collection debug info',
      totalWallets: allWallets.length,
      totalUsers: allUsers.length,
      wallets: allWallets,
      users: allUsers.map(u => ({ id: u._id, name: u.name, email: u.email })),
      testUserId: testUserId,
      testWallet: testWallet,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Error in debugWallets:', error);
    res.status(500).json({
      success: false,
      message: 'Error debugging wallets',
      error: error.message
    });
  }
};

const deductFromWallet = async (req, res) => {
  try {
    const userId = req.user.id;
    const { amount, description } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid amount provided'
      });
    }

    let wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'Wallet not found'
      });
    }

    if (wallet.balance < amount) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient balance',
        currentBalance: wallet.balance,
        requiredAmount: amount
      });
    }

    wallet.balance -= amount;
    wallet.lastUpdated = new Date();
    await wallet.save();

    res.status(200).json({
      success: true,
      message: 'Amount deducted successfully',
      deductedAmount: amount,
      newBalance: wallet.balance,
      description: description || 'Payment deduction'
    });

  } catch (error) {
    console.error('Error deducting from wallet:', error);
    res.status(500).json({
      success: false,
      message: 'Error deducting from wallet',
      error: error.message
    });
  }
};

module.exports = {
  getWalletBalance,
  initializeAllUserWallets,
  createWalletForNewUser,
  addGemsToUser,
  convertGemsToBalance,
  testWallet,
  debugWallets,
  deductFromWallet
};
