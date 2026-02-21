import { describe, it, expect, vi, beforeEach } from "vitest";
import { rateLimit, setRateLimitStore, type RateLimitStore } from "../rate-limit";

// ── Test helpers ────────────────────────────────────────────────

function createMockReqRes(ip = "127.0.0.1") {
  const req = { ip } as any;
  const res = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  } as any;
  const next = vi.fn();
  return { req, res, next };
}

// ── Tests ───────────────────────────────────────────────────────

describe("rateLimit middleware", () => {
  beforeEach(() => {
    // Reset to a fresh in-memory store for each test.
    const freshStore: RateLimitStore = {
      increment(key: string, windowMs: number) {
        const counts = (freshStore as any)._counts ??= new Map();
        const now = Date.now();
        const entry = counts.get(key);

        if (!entry || now > entry.resetAt) {
          counts.set(key, { count: 1, resetAt: now + windowMs });
          return { count: 1, limited: false };
        }
        entry.count++;
        return { count: entry.count, limited: false };
      },
    };
    setRateLimitStore(freshStore);
  });

  it("allows requests under the limit", () => {
    const middleware = rateLimit(5, 60_000);
    const { req, res, next } = createMockReqRes();

    middleware(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  it("blocks requests over the limit", () => {
    const middleware = rateLimit(3, 60_000);

    for (let i = 0; i < 3; i++) {
      const { req, res, next } = createMockReqRes();
      middleware(req, res, next);
      expect(next).toHaveBeenCalled();
    }

    // 4th request should be blocked
    const { req, res, next } = createMockReqRes();
    middleware(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(429);
    expect(res.json).toHaveBeenCalledWith({ error: "Too many requests" });
  });

  it("tracks different IPs independently", () => {
    const middleware = rateLimit(2, 60_000);

    // IP 1: 2 requests (at limit)
    for (let i = 0; i < 2; i++) {
      const { req, res, next } = createMockReqRes("1.1.1.1");
      middleware(req, res, next);
      expect(next).toHaveBeenCalled();
    }

    // IP 2 should still be allowed
    const { req, res, next } = createMockReqRes("2.2.2.2");
    middleware(req, res, next);
    expect(next).toHaveBeenCalled();

    // IP 1 should be blocked
    const r2 = createMockReqRes("1.1.1.1");
    middleware(r2.req, r2.res, r2.next);
    expect(r2.next).not.toHaveBeenCalled();
    expect(r2.res.status).toHaveBeenCalledWith(429);
  });

  it("supports custom async store", async () => {
    let callCount = 0;

    const asyncStore: RateLimitStore = {
      async increment(_key: string, _windowMs: number) {
        callCount++;
        return { count: callCount, limited: false };
      },
    };
    setRateLimitStore(asyncStore);

    const middleware = rateLimit(2, 60_000);

    // First request — should be allowed
    const { req, res, next } = createMockReqRes();
    middleware(req, res, next);

    // Wait for the async resolution
    await new Promise((r) => setTimeout(r, 10));

    expect(next).toHaveBeenCalled();
    expect(callCount).toBe(1);
  });

  it("store returning limited=true blocks immediately", () => {
    const limitedStore: RateLimitStore = {
      increment() {
        return { count: 1, limited: true };
      },
    };
    setRateLimitStore(limitedStore);

    const middleware = rateLimit(100, 60_000);
    const { req, res, next } = createMockReqRes();
    middleware(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(429);
  });

  it("async store errors fail open (allow the request)", async () => {
    const errorStore: RateLimitStore = {
      async increment() {
        throw new Error("Redis connection lost");
      },
    };
    setRateLimitStore(errorStore);

    const middleware = rateLimit(10, 60_000);
    const { req, res, next } = createMockReqRes();
    middleware(req, res, next);

    await new Promise((r) => setTimeout(r, 10));

    // Should fail open — request allowed
    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });
});
