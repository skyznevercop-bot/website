import { Router, Request, Response } from "express";

/**
 * Solana RPC proxy — forwards JSON-RPC requests from the browser to a
 * server-side Solana RPC endpoint, bypassing CORS restrictions that block
 * direct browser → Solana RPC calls.
 *
 * The browser sends the exact JSON-RPC body it would send to a Solana node;
 * we forward it and relay the response.
 */

const router = Router();

// RPCs to try, in order.  The first that responds 200 wins.
const RPC_ENDPOINTS = [
  "https://solana-rpc.publicnode.com",
  "https://api.mainnet-beta.solana.com",
  "https://solana-mainnet.g.alchemy.com/v2/demo",
];

router.post("/", async (req: Request, res: Response) => {
  const body = JSON.stringify(req.body);

  for (const rpc of RPC_ENDPOINTS) {
    try {
      const upstream = await fetch(rpc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        signal: AbortSignal.timeout(8_000),
      });

      if (!upstream.ok) continue; // try next RPC

      const data = await upstream.json();
      res.json(data);
      return;
    } catch {
      // RPC unreachable — try next
    }
  }

  res.status(502).json({
    jsonrpc: "2.0",
    error: { code: -32000, message: "All upstream Solana RPCs failed" },
    id: req.body?.id ?? null,
  });
});

export default router;
