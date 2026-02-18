import { Router, Request, Response } from "express";

/**
 * Binance klines proxy — fetches 1-minute candlestick data server-side,
 * bypassing any browser-side CORS / geo blocks on api.binance.com.
 *
 * GET /api/klines/:symbol?interval=1m&limit=300
 */
const router = Router();

router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = (req.params.symbol || "BTCUSDT").toUpperCase();
  const interval = (req.query.interval as string) || "1m";
  const limit = Math.min(parseInt((req.query.limit as string) || "300", 10), 1000);

  const url = `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=${interval}&limit=${limit}`;

  try {
    const upstream = await fetch(url, {
      signal: AbortSignal.timeout(8_000),
    });

    if (!upstream.ok) {
      res.status(upstream.status).json({ error: "Binance upstream error" });
      return;
    }

    const data = await upstream.json();
    // Cache for 10s — candles don't change faster than that
    res.set("Cache-Control", "public, max-age=10");
    res.json(data);
  } catch (err) {
    console.error(`[Klines] Fetch failed for ${symbol}:`, err);
    res.status(502).json({ error: "Failed to fetch klines from Binance" });
  }
});

export default router;
