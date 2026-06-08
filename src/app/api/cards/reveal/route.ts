import {
  ApiError,
  assertVerifiedSession,
  authenticateBearer,
  db,
  encryptForClient,
  handleApiError,
  jsonResponse,
  stripe,
  stripeRequestOptions,
} from "../_lib/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await authenticateBearer(request);
    assertVerifiedSession(session);

    const body = await request.json().catch(() => ({}));
    const publicKey = body.publicKey;

    if (typeof publicKey !== "string" || !publicKey.trim()) {
      throw new ApiError(400, "publicKey is required.");
    }

    const walletSnapshot = await db.collection("wallets").doc(session.uid).get();
    const wallet = walletSnapshot.exists ? walletSnapshot.data() ?? {} : {};
    const cardId = wallet.stripeCardId;

    if (typeof cardId !== "string" || !cardId) {
      throw new ApiError(404, "No Stripe Issuing card is linked to this wallet.");
    }

    const card = await stripe.issuing.cards.retrieve(
      cardId,
      { expand: ["number", "cvc"] },
      stripeRequestOptions,
    );
    const sensitiveCard = card as typeof card & { number?: string | null; cvc?: string | null };

    if (!sensitiveCard.number || !sensitiveCard.cvc) {
      throw new ApiError(502, "Stripe did not return revealable card details.");
    }

    const encrypted = await encryptForClient(publicKey, {
      cardId: card.id,
      number: sensitiveCard.number,
      cvc: sensitiveCard.cvc,
      expMonth: card.exp_month,
      expYear: card.exp_year,
    });

    return jsonResponse({ encrypted });
  } catch (error) {
    return handleApiError(error);
  }
}
