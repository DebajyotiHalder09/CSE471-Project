const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name: String,
    email: String,
    gender: String,
    role: String,
    password: String,
    preferences: {
        preferredBuses: [String],
        avoidRoutes: [String]
    }
}, { timestamps: true });

module.exports = mongoose.model('User', UserSchema);
