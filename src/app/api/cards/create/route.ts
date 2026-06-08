import {
  assertVerifiedSession,
  authenticateBearer,
  buildCardholderParams,
  db,
  handleApiError,
  jsonResponse,
  stripe,
  stripeRequestOptions,
  walletCardUpdate,
} from "../_lib/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await authenticateBearer(request);
    assertVerifiedSession(session);

    const walletRef = db.collection("wallets").doc(session.uid);
    const walletSnapshot = await walletRef.get();
    const wallet = walletSnapshot.exists ? walletSnapshot.data() ?? {} : {};

    if (typeof wallet.stripeCardId === "string" && wallet.stripeCardId) {
      const existingCard = await stripe.issuing.cards.retrieve(
        wallet.stripeCardId,
        stripeRequestOptions,
      );

      return jsonResponse(cardResponse(existingCard));
    }

    const cardholder = await stripe.issuing.cardholders.create(
      buildCardholderParams(session, wallet),
      {
        ...stripeRequestOptions,
        idempotencyKey: `beam-cardholder-${session.uid}`,
      },
    );

    const card = await stripe.issuing.cards.create(
      {
        cardholder: cardholder.id,
        currency: "usd",
        type: "virtual",
        status: "active",
        metadata: {
          firebaseUid: session.uid,
          walletPath: `wallets/${session.uid}`,
        },
      },
      {
        ...stripeRequestOptions,
        idempotencyKey: `beam-virtual-card-${session.uid}`,
      },
    );

    await walletRef.set(walletCardUpdate(cardholder.id, card.id), { merge: true });

    return jsonResponse(cardResponse(card), 201);
  } catch (error) {
    return handleApiError(error);
  }
}

function cardResponse(card: Awaited<ReturnType<typeof stripe.issuing.cards.retrieve>>) {
  return {
    cardId: card.id,
    cardholderId:
      typeof card.cardholder === "string" ? card.cardholder : card.cardholder?.id,
    brand: card.brand,
    last4: card.last4,
    expMonth: card.exp_month,
    expYear: card.exp_year,
    status: card.status,
    type: card.type,
    wallets: card.wallets,
  };
}
