import { Request, Response, NextFunction } from "express";

// ── Rate Limit Store Interface ─────────────────────────────────
// Swap the implementation to Redis for multi-instance deployments.

export interface RateLimitStore {
  /** Increment the counter for a key. Returns the new count and whether the window was reset. */
  increment(key: string, windowMs: number): Promise<{ count: number; limited: boolean }> | { count: number; limited: boolean };
  /** Called periodically to clean up expired entries (in-memory only). */
  cleanup?(): void;
}

// ── In-Memory Store (default, single-instance) ─────────────────

/** Maximum tracked IPs to prevent unbounded memory growth under DDoS. */
const MAX_TRACKED_IPS = 50_000;

class InMemoryRateLimitStore implements RateLimitStore {
  private counts = new Map<string, { count: number; resetAt: number }>();
  private cleanupTimer: ReturnType<typeof setInterval>;

  constructor() {
    // Periodically purge expired entries.
    this.cleanupTimer = setInterval(() => this.cleanup(), 60_000);
  }

  increment(key: string, windowMs: number): { count: number; limited: boolean } {
    const now = Date.now();
    const entry = this.counts.get(key);

    if (!entry || now > entry.resetAt) {
      // Reject new entries if the map is full (DDoS protection).
      if (!entry && this.counts.size >= MAX_TRACKED_IPS) {
        return { count: MAX_TRACKED_IPS, limited: true };
      }
      this.counts.set(key, { count: 1, resetAt: now + windowMs });
      return { count: 1, limited: false };
    }

    entry.count++;
    return { count: entry.count, limited: false };
  }

  cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.counts) {
      if (now > entry.resetAt) {
        this.counts.delete(key);
      }
    }
  }

  destroy(): void {
    clearInterval(this.cleanupTimer);
  }
}

// ── Singleton store ────────────────────────────────────────────

let activeStore: RateLimitStore = new InMemoryRateLimitStore();

/**
 * Replace the rate limit store (e.g. with a Redis-backed implementation).
 *
 * Usage with Redis (example):
 * ```ts
 * import { setRateLimitStore } from "./middleware/rate-limit";
 * import { RedisRateLimitStore } from "./stores/redis-rate-limit";
 *
 * setRateLimitStore(new RedisRateLimitStore(redisClient));
 * ```
 */
export function setRateLimitStore(store: RateLimitStore): void {
  activeStore = store;
}

// ── Middleware ──────────────────────────────────────────────────

/**
 * Rate limiting middleware.
 *
 * Uses an in-memory store by default. For production multi-instance
 * deployments, call `setRateLimitStore()` with a Redis-backed store
 * before starting the server.
 */
export function rateLimit(maxRequests: number, windowMs: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const key = req.ip || "unknown";
    const result = activeStore.increment(key, windowMs);

    // Handle both sync and async stores.
    if (result instanceof Promise) {
      result.then(({ count, limited }) => {
        if (limited || count > maxRequests) {
          res.status(429).json({ error: "Too many requests" });
          return;
        }
        next();
      }).catch((err) => {
        console.error("[RateLimit] Store error, allowing request:", err);
        next(); // Fail open — don't block requests if the store is down.
      });
    } else {
      if (result.limited || result.count > maxRequests) {
        res.status(429).json({ error: "Too many requests" });
        return;
      }
      next();
    }
  };
}
