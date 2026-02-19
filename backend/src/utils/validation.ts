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
