/**
 * Shared input validation for queue/balance operations.
 * Prevents NaN, Infinity, path injection, and arbitrary values.
 */

// ── Allowed values (must match frontend AppConstants) ────────────

export const VALID_DURATIONS = ["5m", "15m", "1h", "4h", "24h"] as const;
export const VALID_BETS = [5, 10, 50, 100, 1000] as const;

export type ValidDuration = (typeof VALID_DURATIONS)[number];
export type ValidBet = (typeof VALID_BETS)[number];

// ── Validators ───────────────────────────────────────────────────

/** Check that a value is a finite, positive number (not NaN, Infinity, or negative). */
export function isFinitePositive(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

/** Check that duration is one of the allowed values. */
export function isValidDuration(value: unknown): value is ValidDuration {
  return typeof value === "string" && (VALID_DURATIONS as readonly string[]).includes(value);
}

/** Check that bet is one of the allowed values. */
export function isValidBet(value: unknown): value is ValidBet {
  return isFinitePositive(value) && (VALID_BETS as readonly number[]).includes(value);
}

// ── String sanitization ─────────────────────────────────────────

/**
 * Strip control characters (except common whitespace) from user-supplied text.
 * Prevents null-byte injection, terminal escape sequences, and other
 * invisible characters from being stored or broadcast.
 */
export function sanitizeText(input: string): string {
  // Remove C0/C1 control chars except \t (\x09) and \n (\x0A).
  // eslint-disable-next-line no-control-regex
  return input.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F\x80-\x9F]/g, "").trim();
}

/**
 * Validate a Solana wallet address (base58 encoded, 32-44 chars).
 * Does NOT verify on-chain existence — just format plausibility.
 */
export function isValidSolanaAddress(value: unknown): value is string {
  if (typeof value !== "string") return false;
  // Solana base58 addresses are 32–44 characters and contain only base58 chars.
  return /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(value);
}
