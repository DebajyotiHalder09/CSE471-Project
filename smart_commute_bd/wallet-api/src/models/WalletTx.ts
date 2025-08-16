import { Schema, model } from "mongoose";

const schema = new Schema(
  {
    _id: { type: String, required: true }, // "txn_<uuid>"
    userId: { type: String, required: true, index: true },
    type: { type: String, enum: ["CREDIT", "DEBIT"], required: true },
    source: { type: String, enum: ["TOPUP", "REFUND", "ADJUSTMENT", "PURCHASE_REVERSAL"], required: true },
    amountPaisa: { type: Number, required: true },
    runningBalancePaisa: { type: Number, required: true },
    refTopupId: String
  },
  { timestamps: true }
);

export default model("WalletTx", schema);

