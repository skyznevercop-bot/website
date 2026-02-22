import { Router, Request, Response } from "express";
import { rateLimit } from "../middleware/rate-limit";

/**
 * Solana RPC proxy — forwards JSON-RPC requests from the browser to a
 * server-side Solana RPC endpoint, bypassing CORS restrictions that block
 * direct browser → Solana RPC calls.
 *
 * Security hardening:
 *  - Only safe, read-only RPC methods are allowed (method allowlist).
 *  - Stricter rate limit (30 req/min) to prevent abuse as a free relay.
 */

const router = Router();

// Stricter rate limit for the proxy (30 requests per minute per IP).
router.use(rateLimit(30, 60_000));

// RPCs to try, in order.  The first that responds 200 wins.
const RPC_ENDPOINTS = [
  "https://solana-rpc.publicnode.com",
  "https://api.mainnet-beta.solana.com",
  "https://solana-mainnet.g.alchemy.com/v2/demo",
];

/**
 * Allowlist of safe, read-only Solana JSON-RPC methods.
 * Blocks expensive or state-changing methods (e.g. sendTransaction,
 * simulateTransaction, requestAirdrop) that could be abused.
 */
const ALLOWED_METHODS = new Set([
  "getAccountInfo",
  "getBalance",
  "getBlock",
  "getBlockHeight",
  "getBlockTime",
  "getConfirmedTransaction",
  "getEpochInfo",
  "getGenesisHash",
  "getLatestBlockhash",
  "getMinimumBalanceForRentExemption",
  "getMultipleAccounts",
  "getRecentBlockhash",
  "getSignatureStatuses",
  "getSlot",
  "getTokenAccountBalance",
  "getTokenAccountsByOwner",
  "getTransaction",
  "getVersion",
  "isBlockhashValid",
]);

router.post("/", async (req: Request, res: Response) => {
  const method = req.body?.method;

  if (typeof method !== "string" || !ALLOWED_METHODS.has(method)) {
    res.status(403).json({
      jsonrpc: "2.0",
      error: { code: -32601, message: `Method not allowed: ${method ?? "unknown"}` },
      id: req.body?.id ?? null,
    });
    return;
  }

  const body = JSON.stringify(req.body);

  for (const rpc of RPC_ENDPOINTS) {
    try {
      const upstream = await fetch(rpc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        signal: AbortSignal.timeout(8_000),
      });

      if (!upstream.ok) {
        continue;
      }

      const data = await upstream.json();
      res.json(data);
      return;
    } catch (err) {
      console.warn(`[RPC Proxy] ${rpc} failed for ${method}:`, err instanceof Error ? err.message : err);
    }
  }

  res.status(502).json({
    jsonrpc: "2.0",
    error: { code: -32000, message: "All upstream Solana RPCs failed" },
    id: req.body?.id ?? null,
  });
});

export default router;
