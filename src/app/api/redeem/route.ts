import { ApiError, authenticateBearer, db, FieldValue, handleApiError, jsonResponse } from "../../../lib/admin";
import { stripe } from "../../../lib/firebase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await authenticateBearer(request);
    const body = await request.json().catch(() => ({}));
    const amountBeam = Number(body.amountBeam ?? body.amount);

    if (!Number.isFinite(amountBeam) || amountBeam <= 0) {
      throw new ApiError(400, "A positive amountBeam is required.");
    }

    const amountCents = Math.floor(amountBeam * 100);
    if (amountCents <= 0) {
      throw new ApiError(400, "Redemption amount is too small.");
    }

    const walletRef = db.collection("wallets").doc(session.uid);
    const walletSnapshot = await walletRef.get();
    if (!walletSnapshot.exists) {
      throw new ApiError(404, "Wallet not found.");
    }

    const wallet = walletSnapshot.data() ?? {};
    const balanceBeam = Number(wallet.balanceBeam ?? 0);
    const destination = wallet.stripeConnectAccountId;

    if (!Number.isFinite(balanceBeam) || balanceBeam < amountBeam) {
      throw new ApiError(400, "Insufficient BEAM balance.");
    }
    if (typeof destination !== "string" || !destination) {
      throw new ApiError(422, "Stripe Connect onboarding is required before cash out.");
    }

    const transfer = await stripe.transfers.create(
      {
        amount: amountCents,
        currency: "usd",
        destination,
        metadata: {
          firebaseUid: session.uid,
          walletPath: `wallets/${session.uid}`,
          amountBeam: String(amountBeam),
        },
      },
      {
        idempotencyKey: `beam-redemption-${session.uid}-${Date.now()}`,
      },
    );

    const newBalance = await db.runTransaction(async (transaction) => {
      const latestWalletSnapshot = await transaction.get(walletRef);
      const latestWallet = latestWalletSnapshot.data() ?? {};
      const latestBalance = Number(latestWallet.balanceBeam ?? 0);

      if (!Number.isFinite(latestBalance) || latestBalance < amountBeam) {
        throw new ApiError(400, "Insufficient BEAM balance.");
      }

      const nextBalance = latestBalance - amountBeam;
      transaction.set(
        walletRef,
        {
          balanceBeam: FieldValue.increment(-amountBeam),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const redemptionRef = db.collection("beamTransactions").doc();
      transaction.set(redemptionRef, {
        uid: session.uid,
        walletPath: `wallets/${session.uid}`,
        type: "redemption",
        status: "completed",
        amountBeam,
        amountCents,
        currency: "usd",
        stripeTransferId: transfer.id,
        stripeConnectAccountId: destination,
        createdAt: FieldValue.serverTimestamp(),
      });

      return nextBalance;
    });

    return jsonResponse({
      success: true,
      transferId: transfer.id,
      newBalance,
    });
  } catch (error) {
    return handleApiError(error);
  }
}
