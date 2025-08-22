const Gpay = require('../models/gpay');
const User = require('../models/user');
const Wallet = require('../models/wallet');
const bcrypt = require('bcryptjs');

const generateUniqueCode = () => {
  return Math.floor(1000 + Math.random() * 9000).toString();
};

const registerGpay = async (req, res) => {
  try {
    const userId = req.user._id;
    
    const existingGpay = await Gpay.findOne({ userId });
    if (existingGpay) {
      return res.status(400).json({ 
        success: false, 
        message: 'User already has a Gpay account' 
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ 
        success: false, 
        message: 'User not found' 
      });
    }

    const wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      return res.status(404).json({ 
        success: false, 
        message: 'Wallet not found' 
      });
    }

    let displayCode;
    let isUnique = false;
    
    while (!isUnique) {
      displayCode = generateUniqueCode();
      const existingCode = await Gpay.findOne({ displayCode });
      if (!existingCode) {
        isUnique = true;
      }
    }

    const hashedCode = await bcrypt.hash(displayCode, 10);

    const gpayAccount = new Gpay({
      userId,
      walletId: wallet._id,
      balance: 1000,
      code: hashedCode,
      displayCode
    });

    await gpayAccount.save();

    res.status(201).json({
      success: true,
      message: 'Gpay account created successfully',
      data: {
        balance: gpayAccount.balance,
        displayCode: gpayAccount.displayCode
      }
    });
  } catch (error) {
    console.error('Error in registerGpay:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

const loginGpay = async (req, res) => {
  try {
    const { code } = req.body;
    const userId = req.user._id;

    if (!code) {
      return res.status(400).json({ 
        success: false, 
        message: 'PIN code is required' 
      });
    }

    const gpayAccount = await Gpay.findOne({ userId });
    if (!gpayAccount) {
      return res.status(404).json({ 
        success: false, 
        message: 'Gpay account not found. Please register first.' 
      });
    }

    const isValidCode = await bcrypt.compare(code, gpayAccount.code);
    if (!isValidCode) {
      return res.status(401).json({ 
        success: false, 
        message: 'Invalid PIN code' 
      });
    }

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        balance: gpayAccount.balance,
        displayCode: gpayAccount.displayCode
      }
    });
  } catch (error) {
    console.error('Error in loginGpay:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

const getGpayBalance = async (req, res) => {
  try {
    const userId = req.user._id;

    const gpayAccount = await Gpay.findOne({ userId });
    if (!gpayAccount) {
      return res.status(404).json({ 
        success: false, 
        message: 'Gpay account not found' 
      });
    }

    res.status(200).json({
      success: true,
      data: {
        balance: gpayAccount.balance,
        displayCode: gpayAccount.displayCode
      }
    });
  } catch (error) {
    console.error('Error in getGpayBalance:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

module.exports = {
  registerGpay,
  loginGpay,
  getGpayBalance
};
