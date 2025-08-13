
import { Schema, model } from "mongoose";

const schema = new Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    balancePaisa: { type: Number, required: true, default: 0 }
  },
  { timestamps: true }
);

export default model("Wallet", schema);










