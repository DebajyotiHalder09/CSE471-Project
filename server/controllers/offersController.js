const Offers = require('../models/offers');
const User = require('../models/user');
const Wallet = require('../models/wallet');

const createOffersForUser = async (userId, walletId) => {
  try {
    const existingOffers = await Offers.findOne({ userId });
    if (existingOffers) {
      return existingOffers;
    }

    const newOffers = new Offers({
      userId,
      walletId,
      cashback: 0,
      coupon: 0,
      discount: 0,
      isActive: true
    });

    await newOffers.save();
    return newOffers;
  } catch (error) {
    throw new Error(`Failed to create offers for user: ${error.message}`);
  }
};

const getUserOffers = async (req, res) => {
  try {
    const offers = await Offers.findOne({ userId: req.user._id })
      .populate('walletId', 'balance gems currency');

    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    res.status(200).json(offers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateUserOffers = async (req, res) => {
  try {
    const { cashback, coupon, discount, isActive } = req.body;
    const userId = req.user._id;

    const offers = await Offers.findOneAndUpdate(
      { userId },
      { cashback, coupon, discount, isActive },
      { new: true, runValidators: true }
    ).populate('walletId', 'balance gems currency');

    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    res.status(200).json(offers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const addCashback = async (req, res) => {
  try {
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOneAndUpdate(
      { userId },
      { $inc: { cashback: amount } },
      { new: true, runValidators: true }
    ).populate('walletId', 'balance gems currency');

    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    res.status(200).json(offers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const addCoupon = async (req, res) => {
  try {
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOneAndUpdate(
      { userId },
      { $inc: { coupon: amount } },
      { new: true, runValidators: true }
    ).populate('walletId', 'balance gems currency');

    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    res.status(200).json(offers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const addDiscount = async (req, res) => {
  try {
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOneAndUpdate(
      { userId },
      { $inc: { discount: amount } },
      { new: true, runValidators: true }
    ).populate('walletId', 'balance gems currency');

    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    res.status(200).json(offers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const useCashback = async (req, res) => {
  try {
    console.log('DEBUG: useCashback called');
    console.log('DEBUG: Request body:', req.body);
    console.log('DEBUG: User ID:', req.user._id);
    
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      console.log('DEBUG: Invalid amount:', amount);
      return res.status(400).json({ error: 'Invalid amount' });
    }

    console.log('DEBUG: Looking for offers with userId:', userId);
    const offers = await Offers.findOne({ userId });
    if (!offers) {
      console.log('DEBUG: No offers found for user');
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    console.log('DEBUG: Found offers:', offers);
    console.log('DEBUG: Current cashback balance:', offers.cashback);
    console.log('DEBUG: Requested amount:', amount);

    if (offers.cashback < amount) {
      console.log('DEBUG: Insufficient cashback balance');
      return res.status(400).json({ error: 'Insufficient cashback balance' });
    }

    console.log('DEBUG: Looking for wallet with userId:', userId);
    const wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      console.log('DEBUG: No wallet found for user');
      return res.status(404).json({ error: 'No wallet found for this user' });
    }

    console.log('DEBUG: Found wallet:', wallet);
    console.log('DEBUG: Current wallet balance:', wallet.balance);

    const oldCashback = offers.cashback;
    const oldWalletBalance = wallet.balance;

    offers.cashback -= amount;
    wallet.balance += amount;
    wallet.lastUpdated = new Date();

    console.log('DEBUG: Updated offers cashback:', offers.cashback);
    console.log('DEBUG: Updated wallet balance:', wallet.balance);

    await Promise.all([offers.save(), wallet.save()]);

    console.log('DEBUG: Both documents saved successfully');

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    console.log('DEBUG: Sending response with updated data');

    res.status(200).json({
      offers: updatedOffers,
      wallet: wallet,
      message: `Successfully converted ৳${amount} cashback to wallet balance`
    });
  } catch (error) {
    console.error('DEBUG: Error in useCashback:', error);
    res.status(500).json({ error: error.message });
  }
};

const useCoupon = async (req, res) => {
  try {
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOne({ userId });
    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    if (offers.coupon < amount) {
      return res.status(400).json({ error: 'Insufficient coupon balance' });
    }

    const wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      return res.status(404).json({ error: 'No wallet found for this user' });
    }

    offers.coupon -= amount;
    wallet.balance += amount;
    wallet.lastUpdated = new Date();

    await Promise.all([offers.save(), wallet.save()]);

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    res.status(200).json({
      offers: updatedOffers,
      wallet: wallet,
      message: `Successfully converted ৳${amount} coupon to wallet balance`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const useDiscount = async (req, res) => {
  try {
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOne({ userId });
    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    if (offers.discount < amount) {
      return res.status(400).json({ error: 'Insufficient discount balance' });
    }

    const wallet = await Wallet.findOne({ userId });
    if (!wallet) {
      return res.status(404).json({ error: 'No wallet found for this user' });
    }

    offers.discount -= amount;
    wallet.balance += amount;
    wallet.lastUpdated = new Date();

    await Promise.all([offers.save(), wallet.save()]);

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    res.status(200).json({
      offers: updatedOffers,
      wallet: wallet,
      message: `Successfully converted ৳${amount} discount to wallet balance`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  createOffersForUser,
  getUserOffers,
  updateUserOffers,
  addCashback,
  addCoupon,
  addDiscount,
  useCashback,
  useCoupon,
  useDiscount
};
