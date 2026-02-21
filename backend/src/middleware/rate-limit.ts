import { Request, Response, NextFunction } from "express";

const requestCounts = new Map<string, { count: number; resetAt: number }>();

/** Maximum tracked IPs to prevent unbounded memory growth under DDoS. */
const MAX_TRACKED_IPS = 50_000;

// Periodically purge expired entries to prevent unbounded memory growth.
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of requestCounts) {
    if (now > entry.resetAt) {
      requestCounts.delete(key);
    }
  }
}, 60_000);

/**
 * Simple in-memory rate limiter.
 * For production, use Redis-backed rate limiting.
 */
export function rateLimit(maxRequests: number, windowMs: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const key = req.ip || "unknown";
    const now = Date.now();

    const entry = requestCounts.get(key);
    if (!entry || now > entry.resetAt) {
      // Reject new entries if the map is full (DDoS protection).
      if (!entry && requestCounts.size >= MAX_TRACKED_IPS) {
        res.status(429).json({ error: "Too many requests" });
        return;
      }
      requestCounts.set(key, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    if (entry.count >= maxRequests) {
      res.status(429).json({ error: "Too many requests" });
      return;
    }

    entry.count++;
    next();
  };
}
