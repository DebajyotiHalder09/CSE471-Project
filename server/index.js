const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Check for required environment variables
if (!process.env.JWT_SECRET) {
  // If JWT_SECRET is not in .env, use a default one for development
  process.env.JWT_SECRET = '';
  console.log('Using default JWT_SECRET for development');
}

if (!process.env.MONGO_URL) {
  // If MONGO_URL is not in .env, use a default one for development
  process.env.MONGO_URL = '';
  console.log('Using default MONGO_URL for development');
}

// Middleware
app.use(cors());
app.use(express.json());

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URL)
  .then(() => console.log('Connected to MongoDB'))
  .catch((err) => console.error('MongoDB connection error:', err));

// Routes
app.use('/auth', require('./routes/auth'));
app.use('/bus', require('./routes/bus'));

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});