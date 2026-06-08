import { ApiError, authenticateBearer, db, FieldValue, handleApiError, jsonResponse } from "../../../../lib/admin";
import { stripe } from "../../../../lib/firebase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const refreshUrl = "https://fcu.beamthinktank.space/connect/refresh";
const returnUrl = "https://fcu.beamthinktank.space/connect/complete";

export async function POST(request: Request) {
  try {
    const session = await authenticateBearer(request);
    const walletRef = db.collection("wallets").doc(session.uid);
    const walletSnapshot = await walletRef.get();
    const wallet = walletSnapshot.exists ? walletSnapshot.data() ?? {} : {};

    let accountId = wallet.stripeConnectAccountId;
    if (typeof accountId !== "string" || !accountId) {
      const account = await stripe.accounts.create(
        {
          type: "express",
          metadata: {
            firebaseUid: session.uid,
            walletPath: `wallets/${session.uid}`,
          },
        },
        {
          idempotencyKey: `beam-connect-account-${session.uid}`,
        },
      );
      accountId = account.id;

      await walletRef.set(
        {
          stripeConnectAccountId: accountId,
          stripeConnectCreatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: refreshUrl,
      return_url: returnUrl,
      type: "account_onboarding",
    });

    return jsonResponse({
      url: accountLink.url,
      stripeConnectAccountId: accountId,
    });
  } catch (error) {
    return handleApiError(error);
  }
}
