const FavBus = require('../models/favBus');

const addToFavorites = async (req, res) => {
  try {
    const { userId, busId, busName, routeNumber, operator } = req.body;

    if (!userId || !busId || !busName) {
      return res.status(400).json({
        success: false,
        message: 'User ID, bus ID, and bus name are required'
      });
    }

    const existingFav = await FavBus.findOne({ userId, busId });

    if (existingFav) {
      return res.status(400).json({
        success: false,
        message: 'Bus is already in favorites'
      });
    }

    const newFav = new FavBus({
      userId,
      busId,
      busName,
      routeNumber,
      operator
    });

    await newFav.save();

    res.status(201).json({
      success: true,
      message: 'Bus added to favorites',
      data: newFav
    });

  } catch (error) {
    console.error('Error adding bus to favorites:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

const removeFromFavorites = async (req, res) => {
  try {
    const { userId, busId } = req.body;

    if (!userId || !busId) {
      return res.status(400).json({
        success: false,
        message: 'User ID and bus ID are required'
      });
    }

    const result = await FavBus.findOneAndDelete({ userId, busId });

    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Favorite bus not found'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Bus removed from favorites'
    });

  } catch (error) {
    console.error('Error removing bus from favorites:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

const getUserFavorites = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    const favorites = await FavBus.find({ userId }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: favorites,
      count: favorites.length
    });

  } catch (error) {
    console.error('Error getting user favorites:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

const checkIfFavorited = async (req, res) => {
  try {
    const { userId, busId } = req.query;

    if (!userId || !busId) {
      return res.status(400).json({
        success: false,
        message: 'User ID and bus ID are required'
      });
    }

    const favorite = await FavBus.findOne({ userId, busId });

    res.status(200).json({
      success: true,
      isFavorited: !!favorite
    });

  } catch (error) {
    console.error('Error checking favorite status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

module.exports = {
  addToFavorites,
  removeFromFavorites,
  getUserFavorites,
  checkIfFavorited
};
