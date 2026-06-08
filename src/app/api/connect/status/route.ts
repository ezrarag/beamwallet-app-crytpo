import { authenticateBearer, db, handleApiError, jsonResponse } from "../../../../lib/admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  try {
    const session = await authenticateBearer(request);
    const walletSnapshot = await db.collection("wallets").doc(session.uid).get();
    const wallet = walletSnapshot.exists ? walletSnapshot.data() ?? {} : {};
    const accountId = wallet.stripeConnectAccountId;
    const connected = typeof accountId === "string" && accountId.length > 0;

    return jsonResponse({ connected });
  } catch (error) {
    return handleApiError(error);
  }
}
