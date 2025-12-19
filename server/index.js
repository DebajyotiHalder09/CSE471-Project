const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// // Check for required environment variables
// if (!process.env.JWT_SECRET) {
//   // If JWT_SECRET is not in .env, use a default one for development
//   process.env.JWT_SECRET = '';
//   console.log('Using default JWT_SECRET for development');
// }

// if (!process.env.MONGO_URL) {
//   // If MONGO_URL is not in .env, use a default one for development
//   process.env.MONGO_URL = '';
//   console.log('Using default MONGO_URL for development');
// }

// Middleware
app.use(cors({
  origin: '*'  // For production, replace '*' with your frontend URL if hosted, e.g., 'https://myapp.com'
}));
app.use(express.json({ limit: '50mb' })); // Increase limit for image uploads
app.use(express.urlencoded({ extended: true, limit: '50mb' })); // For form data

// Connect to MongoDB
const mongoUrl = process.env.MONGO_URL;
console.log('Attempting to connect to MongoDB...');
console.log('MongoDB URL:', mongoUrl);

mongoose.connect(mongoUrl)
  .then(() => {
    console.log('Connected to MongoDB successfully!');
    console.log('Database name:', mongoose.connection.db.databaseName);
    console.log('Connection state:', mongoose.connection.readyState);
    
    // List all collections in the database
    mongoose.connection.db.listCollections().toArray((err, collections) => {
      if (err) {
        console.error('Error listing collections:', err);
      } else {
        console.log('Available collections:', collections.map(c => c.name));
      }
    });
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err);
    console.error('MongoDB URL used:', mongoUrl);
  });

// Routes
app.use('/auth', require('./routes/auth'));
app.use('/bus', require('./routes/bus'));
app.use('/api/reviews', require('./routes/review'));
app.use('/api/rideshare', require('./routes/rideshare'));
app.use('/api/riderequests', require('./routes/riderequest'));
app.use('/api/favbus', require('./routes/favBus'));
app.use('/api/friends', require('./routes/friends'));
app.use('/trip', require('./routes/trip'));
app.use('/individual-bus', require('./routes/individualBus'));
app.use('/wallet', require('./routes/wallet'));
app.use('/offers', require('./routes/offers'));
app.use('/gpay', require('./routes/gpay'));
app.use('/verify', require('./routes/verify'));
app.use('/api/stops', require('./routes/stops'));
app.use('/api/chat', require('./routes/chat'));

// Test route to verify server is working
app.get('/test', (req, res) => {
  res.json({ message: 'Server is working!' });
});

// Public root route for testing in emulator Chrome
app.get('/', (req, res) => {
  res.send('🚍 Bus API is running on port 3000!');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});