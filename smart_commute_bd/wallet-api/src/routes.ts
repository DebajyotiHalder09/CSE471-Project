
import { Router } from "express";
import crypto from "crypto";
import mongoose from "mongoose";
import Wallet from "./models/Wallet";
import TopupAttempt from "./models/TopupAttempt";
import WalletTx from "./models/WalletTx";

const r = Router();
const uuid = () => crypto.randomUUID();

// super simple auth stub
const auth = (req: any, _res: any, next: any) => {
  req.user = { id: req.header("x-user-id") || "demo-user" };
  next();
};

// balance
r.get("/wallet/balance", auth, async (req: any, res) => {
  const w = await Wallet.findOneAndUpdate(
    { userId: req.user.id },
    { $setOnInsert: { balancePaisa: 0 } },
    { upsert: true, new: true }
  );
  res.json({ balance_bdT: w!.balancePaisa, currency: "BDT", updated_at: w!.updatedAt });
});

// transactions
r.get("/wallet/transactions", auth, async (req: any, res) => {
  const rows = await WalletTx.find({ userId: req.user.id }).sort({ createdAt: -1 }).limit(50);
  res.json({ data: rows });
});

// create topup (mock success to keep it simple)
r.post("/wallet/topups", auth, async (req: any, res) => {
  const { amount_bdT, provider } = req.body;
  if (!amount_bdT || amount_bdT < 100) return res.status(400).json({ error: { code: "invalid_amount" } });
  if (!["BKASH", "NAGAD", "CARD"].includes(provider)) return res.status(400).json({ error: { code: "unsupported_provider" } });

  const id = "top_" + uuid();
  await TopupAttempt.create({
    _id: id,
    userId: req.user.id,
    provider,
    amountPaisa: amount_bdT,
    status: "pending"
  });

  // credit immediately (mock). Replace with real gateway + webhook later.
  await creditIfNotCredited({ topupId: id, providerRef: provider + "_MOCK_TRX_" + Date.now() });

  const updated = await TopupAttempt.findById(id);
  res.status(201).json({
    id,
    status: updated!.status,
    provider,
    amount_bdT,
    provider_ref: updated!.providerRef
  });
});

async function creditIfNotCredited({ topupId, providerRef }: { topupId: string; providerRef: string }) {
  const session = await mongoose.startSession();
  await session.withTransaction(async () => {
    const top = await TopupAttempt.findById(topupId).session(session);
    if (!top) throw new Error("topup_not_found");
    if (top.status === "succeeded") return;

    const wallet = await Wallet.findOneAndUpdate(
      { userId: top.userId },
      { $setOnInsert: { balancePaisa: 0 } },
      { upsert: true, new: true, session }
    );

    const newBal = wallet!.balancePaisa + top.amountPaisa;

    await Wallet.updateOne({ userId: top.userId }, { $set: { balancePaisa: newBal } }, { session });
    await WalletTx.create(
      [
        {
          _id: "txn_" + uuid(),
          userId: top.userId,
          type: "CREDIT",
          source: "TOPUP",
          amountPaisa: top.amountPaisa,
          runningBalancePaisa: newBal,
          refTopupId: top._id
        }
      ],
      { session }
    );

    await TopupAttempt.updateOne(
      { _id: top._id },
      { $set: { status: "succeeded", providerRef, completedAt: new Date() } },
      { session }
    );
  });
  session.endSession();
}

export default r;

