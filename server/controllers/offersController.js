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
    const { amount } = req.body;
    const userId = req.user._id;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const offers = await Offers.findOne({ userId });
    if (!offers) {
      return res.status(404).json({ error: 'No offers found for this user' });
    }

    if (offers.cashback < amount) {
      return res.status(400).json({ error: 'Insufficient cashback balance' });
    }

    offers.cashback -= amount;
    await offers.save();

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    res.status(200).json(updatedOffers);
  } catch (error) {
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

    offers.coupon -= amount;
    await offers.save();

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    res.status(200).json(updatedOffers);
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

    offers.discount -= amount;
    await offers.save();

    const updatedOffers = await Offers.findById(offers._id)
      .populate('walletId', 'balance gems currency');

    res.status(200).json(updatedOffers);
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
