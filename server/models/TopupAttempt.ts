import { Schema, model } from "mongoose";

const schema = new Schema(
  {
    _id: { type: String, required: true }, // e.g., "top_<uuid>"
    userId: { type: String, required: true, index: true },
    provider: { type: String, enum: ["BKASH", "NAGAD", "CARD"], required: true },
    amountPaisa: { type: Number, required: true, min: 1 },
    currency: { type: String, default: "BDT" },
    status: { type: String, required: true, default: "pending" },
    providerRef: { type: String, index: true, sparse: true },
    providerPayload: { type: Schema.Types.Mixed },
    failureCode: String,
    failureMessage: String,
    completedAt: Date
  },
  { timestamps: true }
);

schema.index({ providerRef: 1 }, { unique: true, partialFilterExpression: { providerRef: { $type: "string" } } });

export default model("TopupAttempt", schema);

