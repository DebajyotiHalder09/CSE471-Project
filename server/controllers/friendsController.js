const Friends = require('../models/friends');
const User = require('../models/user');

const getFriends = async (req, res) => {
  try {
    const userId = req.user._id;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    const friendsDoc = await Friends.findOne({ userId }).populate('friends', 'name email gender');
    
    if (!friendsDoc) {
      return res.status(200).json({
        success: true,
        data: [],
        message: 'No friends found for this user'
      });
    }

    const friends = friendsDoc.friends.map(friend => ({
      _id: friend._id,
      name: friend.name,
      email: friend.email,
      gender: friend.gender
    }));

    res.status(200).json({
      success: true,
      data: friends,
      message: 'Friends retrieved successfully'
    });

  } catch (error) {
    console.error('Error fetching friends:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

const addFriend = async (req, res) => {
  try {
    const { userId, friendCode } = req.body;
    
    if (!userId || !friendCode) {
      return res.status(400).json({
        success: false,
        message: 'User ID and friend code are required'
      });
    }

    const friendDoc = await Friends.findOne({ friendCode });
    
    if (!friendDoc) {
      return res.status(404).json({
        success: false,
        message: 'Friend code not found'
      });
    }

    if (friendDoc.userId.toString() === userId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot add yourself as a friend'
      });
    }

    let userFriendsDoc = await Friends.findOne({ userId });
    
    if (!userFriendsDoc) {
      userFriendsDoc = new Friends({
        userId,
        friendCode: await Friends.generateUniqueFriendCode(),
        friends: []
      });
    }

    if (userFriendsDoc.friends.includes(friendDoc.userId)) {
      return res.status(400).json({
        success: false,
        message: 'Already friends with this user'
      });
    }

    userFriendsDoc.friends.push(friendDoc.userId);
    await userFriendsDoc.save();

    res.status(200).json({
      success: true,
      message: 'Friend added successfully'
    });

  } catch (error) {
    console.error('Error adding friend:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

module.exports = {
  getFriends,
  addFriend
};
