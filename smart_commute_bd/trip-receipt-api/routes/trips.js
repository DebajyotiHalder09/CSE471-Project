const express = require("express");
const { v4: uuidv4 } = require("uuid");
const PDFDocument = require("pdfkit");
const Trip = require("../models/Trip");
const router = express.Router();

// Create Trip
router.post("/", async (req, res) => {
  try {
    const { pickupLocation, dropoffLocation, fare, distanceKm } = req.body;
    const trip = new Trip({
      tripId: "TRIP" + Math.floor(Math.random() * 1000000),
      pickupLocation,
      dropoffLocation,
      fare,
      distanceKm
    });
    await trip.save();
    res.status(201).json({ message: "Trip created", trip });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get JSON Receipt
router.get("/:tripId/receipt", async (req, res) => {
  try {
    const trip = await Trip.findOne({ tripId: req.params.tripId });
    if (!trip) return res.status(404).json({ message: "Trip not found" });

    const receipt = {
      tripId: trip.tripId,
      status: trip.status,
      date: trip.date,
      pickupLocation: trip.pickupLocation,
      dropoffLocation: trip.dropoffLocation,
      fare: `${trip.fare} BDT`,
      distance: `${trip.distanceKm} km`
    };

    res.json({ receipt });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Download PDF Receipt
router.get("/:tripId/receipt/pdf", async (req, res) => {
  try {
    const trip = await Trip.findOne({ tripId: req.params.tripId });
    if (!trip) return res.status(404).json({ message: "Trip not found" });

    // Create PDF
    const doc = new PDFDocument();
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename=${trip.tripId}_receipt.pdf`);

    doc.pipe(res);

    // Title
    doc.fontSize(20).text("Trip Receipt", { align: "center" }).moveDown();

    // Trip Info
    doc.fontSize(14)
      .text(`Trip ID: ${trip.tripId}`)
      .text(`Status: ${trip.status}`)
      .text(`Date: ${trip.date.toLocaleString()}`)
      .moveDown();

    // Locations
    doc.text(`Pickup Location: ${trip.pickupLocation}`)
      .text(`Drop-off Location: ${trip.dropoffLocation}`)
      .moveDown();

    // Fare & Distance
    doc.text(`Fare: ${trip.fare} BDT`)
      .text(`Distance: ${trip.distanceKm} km`)
      .moveDown();

    doc.text("Thank you for riding with us!", { align: "center" });

    doc.end();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

