import { getApps, initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

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
export { FieldValue };

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

  console.error("[beam-api]", error);
  return jsonResponse({ error: "Internal server error." }, 500);
}
