const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  gender: {
    type: String,
    required: false,
  },
  role: {
    type: String,
    required: true,
  },
  password: {
    type: String,
    required: true,
  },
}, {
  timestamps: true
});

const User = mongoose.model('users', userSchema);

// Add some debugging to see what collection is being used
console.log('User model created with collection name:', User.collection.name);
console.log('User model database:', User.db.name);

module.exports = User;