const cloudinary = require('cloudinary').v2;
const { Readable } = require('stream');

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
    const { image } = req.body; // Base64 encoded image string (data URI format)

    if (!image) {
      return res.status(400).json({
        success: false,
        message: 'No image provided'
      });
    }

    // Extract base64 string from data URI if present
    // Format: data:image/jpeg;base64,{base64String} or just {base64String}
    let base64String = image;
    if (image.startsWith('data:')) {
      // Extract base64 part after the comma
      const commaIndex = image.indexOf(',');
      if (commaIndex !== -1) {
        base64String = image.substring(commaIndex + 1);
      }
    }

    // Convert base64 string to Buffer
    const imageBuffer = Buffer.from(base64String, 'base64');

    // Create a readable stream from the Buffer
    // Using upload_stream avoids the _Namespace error that occurs with data URI string parsing
    const imageStream = Readable.from(imageBuffer);

    // Upload to Cloudinary using upload_stream (most reliable method for production)
    const uploadResult = await new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'student_verifications',
          resource_type: 'image',
          transformation: [
            { width: 800, height: 800, crop: 'limit' },
            { quality: 'auto' }
          ],
          allowed_formats: ['jpg', 'jpeg', 'png']
        },
        (error, result) => {
          if (error) {
            reject(error);
          } else {
            resolve(result);
          }
        }
      );

      imageStream.pipe(uploadStream);
    });

    res.status(200).json({
      success: true,
      imageUrl: uploadResult.secure_url,
      publicId: uploadResult.public_id
    });
  } catch (error) {
    console.error('Error uploading image to Cloudinary:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
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

