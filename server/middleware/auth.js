const jwt = require('jsonwebtoken');
const User = require('../models/user');

const authenticateToken = async (req, res, next) => {
  try {
    console.log('DEBUG: authenticateToken called');
    console.log('DEBUG: JWT_SECRET exists:', !!process.env.JWT_SECRET);
    console.log('DEBUG: JWT_SECRET length:', process.env.JWT_SECRET?.length);
    
    const token = req.headers.authorization?.split(' ')[1];
    console.log('DEBUG: Token received:', token ? `${token.substring(0, 20)}...` : 'No token');
    
    if (!token) {
      console.log('DEBUG: No token provided');
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    console.log('DEBUG: Verifying token...');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('DEBUG: Token decoded successfully, user ID:', decoded.id);
    
    console.log('DEBUG: Looking up user...');
    const user = await User.findById(decoded.id).select('-password');
    
    if (!user) {
      console.log('DEBUG: User not found');
      return res.status(401).json({ error: 'Invalid token.' });
    }

    console.log('DEBUG: User found:', user._id);
    req.user = user;
    next();
  } catch (error) {
    console.error('DEBUG: Error in authenticateToken:', error);
    res.status(401).json({ error: 'Invalid token.' });
  }
};

module.exports = authenticateToken;
