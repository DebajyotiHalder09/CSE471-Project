const express = require("express");
const mongoose = require("mongoose");
const tripRoutes = require("./routes/trips");

const app = express();
app.use(express.json());

// Connect MongoDB
mongoose.connect("mongodb://localhost:27017/tripdb", {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => console.log("MongoDB connected"))
  .catch(err => console.error(err));

app.use("/api/trips", tripRoutes);

app.listen(1281, () => console.log("Server running on port 1281"));
