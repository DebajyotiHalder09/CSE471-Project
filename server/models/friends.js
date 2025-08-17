const mongoose = require('mongoose');

const friendsSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  friendCode: {
    type: String,
    required: true,
    unique: true,
    length: 5
  },
  friends: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Generate a unique 5-character friend code
friendsSchema.statics.generateUniqueFriendCode = async function() {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let friendCode;
  let isUnique = false;
  
  while (!isUnique) {
    friendCode = '';
    for (let i = 0; i < 5; i++) {
      friendCode += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    
    // Check if this code already exists
    const existing = await this.findOne({ friendCode });
    if (!existing) {
      isUnique = true;
    }
  }
  
  return friendCode;
};

module.exports = mongoose.model('Friends', friendsSchema);
