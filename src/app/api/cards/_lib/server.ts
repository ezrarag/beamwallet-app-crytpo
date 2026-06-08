import { randomBytes, createCipheriv, publicEncrypt, constants } from "crypto";
import { getApps, initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import Stripe from "stripe";

export const runtime = "nodejs";

const STRIPE_ISSUING_ACCOUNT_ID =
  process.env.STRIPE_ISSUING_ACCOUNT_ID ?? "acct_1TdNUd6BZNNqOUDM";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function initFirebaseAdmin() {
  if (getApps().length > 0) return;

  const projectId = requireEnv("FIREBASE_PROJECT_ID");
  const clientEmail = requireEnv("FIREBASE_CLIENT_EMAIL");
  const privateKey = requireEnv("FIREBASE_PRIVATE_KEY").replace(/\\n/g, "\n");

  initializeApp({
    credential: cert({ projectId, clientEmail, privateKey }),
  });
}

initFirebaseAdmin();

export const adminAuth = getAuth();
export const db = getFirestore();

export const stripe = new Stripe(requireEnv("STRIPE_SECRET_KEY"), {
  apiVersion: "2025-07-30.basil",
});

export const stripeRequestOptions: Stripe.RequestOptions = {
  stripeAccount: STRIPE_ISSUING_ACCOUNT_ID,
};

export type AuthedSession = {
  uid: string;
  email?: string;
  name?: string;
  emailVerified: boolean;
};

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

export async function authenticateBearer(request: Request): Promise<AuthedSession> {
  const authorization = request.headers.get("authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    throw new ApiError(401, "Missing Bearer token.");
  }

  const decoded = await adminAuth.verifyIdToken(match[1], true);

  return {
    uid: decoded.uid,
    email: decoded.email,
    name: typeof decoded.name === "string" ? decoded.name : undefined,
    emailVerified: decoded.email_verified === true,
  };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
      "Pragma": "no-cache",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export function handleApiError(error: unknown): Response {
  if (error instanceof ApiError) {
    return jsonResponse({ error: error.message }, error.status);
  }

  console.error("[cards-api]", error);
  return jsonResponse({ error: "Internal server error." }, 500);
}

type WalletData = FirebaseFirestore.DocumentData;

export function assertVerifiedSession(session: AuthedSession) {
  if (!session.emailVerified) {
    throw new ApiError(403, "Verified email is required for card access.");
  }
}

export function buildCardholderParams(
  session: AuthedSession,
  wallet: WalletData,
): Stripe.Issuing.CardholderCreateParams {
  const profile = wallet.verifiedProfile ?? wallet.profile ?? wallet;
  const billing = profile.billing ?? profile.billingAddress ?? profile.address;
  const name = profile.name ?? profile.fullName ?? session.name;
  const email = profile.email ?? session.email;
  const phoneNumber = profile.phoneNumber ?? profile.phone;

  if (!name || !email || !billing) {
    throw new ApiError(
      422,
      "Verified cardholder profile is incomplete. Name, email, and billing address are required.",
    );
  }

  const address = {
    line1: billing.line1 ?? billing.addressLine1,
    line2: billing.line2 ?? billing.addressLine2,
    city: billing.city,
    state: billing.state,
    postal_code: billing.postal_code ?? billing.postalCode ?? billing.zip,
    country: billing.country ?? "US",
  };

  if (!address.line1 || !address.city || !address.state || !address.postal_code) {
    throw new ApiError(
      422,
      "Verified billing address is incomplete. line1, city, state, and postal code are required.",
    );
  }

  return {
    type: "individual",
    name,
    email,
    phone_number: phoneNumber,
    billing: { address },
    metadata: {
      firebaseUid: session.uid,
      walletPath: `wallets/${session.uid}`,
    },
  };
}

export function walletCardUpdate(cardholderId: string, cardId: string) {
  return {
    stripeCardholderId: cardholderId,
    stripeCardId: cardId,
    stripeIssuingAccountId: STRIPE_ISSUING_ACCOUNT_ID,
    stripeCardUpdatedAt: FieldValue.serverTimestamp(),
  };
}

export async function encryptForClient(publicKeyPem: string, payload: unknown) {
  if (!publicKeyPem.includes("BEGIN PUBLIC KEY")) {
    throw new ApiError(400, "A PEM encoded RSA public key is required.");
  }

  const key = randomBytes(32);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const plaintext = Buffer.from(JSON.stringify(payload), "utf8");
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  const wrappedKey = publicEncrypt(
    {
      key: publicKeyPem,
      padding: constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: "sha256",
    },
    key,
  );

  return {
    alg: "RSA-OAEP-256+A256GCM",
    key: wrappedKey.toString("base64"),
    iv: iv.toString("base64"),
    tag: tag.toString("base64"),
    ciphertext: ciphertext.toString("base64"),
  };
}
