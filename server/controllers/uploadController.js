const cloudinary = require('cloudinary').v2;

// Configure Cloudinary
// Priority: 1. CLOUDINARY_URL env variable, 2. Individual env variables
if (process.env.CLOUDINARY_URL) {
  // Format: cloudinary://api_key:api_secret@cloud_name
  cloudinary.config();
} else if (process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
  });
} else {
  console.error('❌ ERROR: Cloudinary credentials not found in environment variables!');
  console.error('Please set CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in your .env file');
  throw new Error('Cloudinary configuration missing. Please check your .env file.');
}

// Upload image to Cloudinary
const uploadImage = async (req, res) => {
  try {
    const { image } = req.body; // Base64 encoded image string

    if (!image) {
      return res.status(400).json({
        success: false,
        message: 'No image provided'
      });
    }

    // Upload to Cloudinary
    // Cloudinary accepts base64 data URI format
    const uploadResult = await cloudinary.uploader.upload(image, {
      folder: 'student_verifications',
      resource_type: 'image',
      transformation: [
        { width: 800, height: 800, crop: 'limit' },
        { quality: 'auto' }
      ],
      allowed_formats: ['jpg', 'jpeg', 'png']
    });

    res.status(200).json({
      success: true,
      imageUrl: uploadResult.secure_url,
      publicId: uploadResult.public_id
    });
  } catch (error) {
    console.error('Error uploading image to Cloudinary:', error);
    res.status(500).json({
      success: false,
      message: 'Error uploading image',
      error: error.message
    });
  }
};

module.exports = {
  uploadImage
};

