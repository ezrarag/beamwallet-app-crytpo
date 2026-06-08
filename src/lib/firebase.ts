import Stripe from "stripe";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const BEAM_REDEMPTION_CENTS_PER_BEAM = Number(
  process.env.BEAM_REDEMPTION_CENTS_PER_BEAM ?? "100",
);

export const stripe = new Stripe(requireEnv("STRIPE_SECRET_KEY"), {
  apiVersion: "2025-07-30.basil",
});
