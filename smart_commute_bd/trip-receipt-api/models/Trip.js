const mongoose = require("mongoose");

const tripSchema = new mongoose.Schema({
  tripId: { type: String, required: true, unique: true },
  status: { type: String, enum: ["Completed", "Ongoing", "Cancelled"], default: "Completed" },
  pickupLocation: { type: String, required: true },
  dropoffLocation: { type: String, required: true },
  date: { type: Date, default: Date.now },
  fare: { type: Number, required: true },
  distanceKm: { type: Number, required: true }
});

module.exports = mongoose.model("Trip", tripSchema);
