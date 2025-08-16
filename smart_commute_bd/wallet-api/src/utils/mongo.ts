import mongoose from "mongoose";

export async function connectMongo(uri: string) {
  try {
    mongoose.set("strictQuery", true);
    await mongoose.connect(uri);
    console.log("✅ MongoDB connected");
  } catch (e) {
    console.error("❌ Mongo connect error:", e);
    process.exit(1);
  }
}


