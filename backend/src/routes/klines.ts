import { Router, Request, Response } from "express";

/**
 * Klines (candlestick) proxy — fetches 1-minute OHLC data server-side.
 *
 * Uses Kraken as the primary source (no US geo-block) and Bybit as fallback.
 * Returns data in Binance klines format so the frontend JS needs no changes:
 *   [ [openTimeMs, open, high, low, close, ...], ... ]
 *
 * GET /api/klines/:symbol   (symbol e.g. "BTCUSDT")
 */
const router = Router();

// Map Binance-style symbols to Kraken pairs
const KRAKEN_PAIRS: Record<string, string> = {
  BTCUSDT: "XBTUSD",
  ETHUSDT: "ETHUSD",
  SOLUSDT: "SOLUSD",
};

// Map Binance-style symbols to Bybit pairs (fallback)
const BYBIT_PAIRS: Record<string, string> = {
  BTCUSDT: "BTCUSDT",
  ETHUSDT: "ETHUSDT",
  SOLUSDT: "SOLUSDT",
};

async function fetchKraken(symbol: string, limit: number): Promise<unknown[] | null> {
  const pair = KRAKEN_PAIRS[symbol];
  if (!pair) return null;

  // Kraken returns up to 720 1-minute candles
  const since = Math.floor(Date.now() / 1000) - limit * 60;
  const url = `https://api.kraken.com/0/public/OHLC?pair=${pair}&interval=1&since=${since}`;

  const resp = await fetch(url, { signal: AbortSignal.timeout(8_000) });
  if (!resp.ok) return null;

  const json = await resp.json() as { error: string[]; result: Record<string, unknown[][]> };
  if (json.error && json.error.length > 0) return null;

  // Kraken result key is the pair name (may differ from requested, e.g. XXBTZUSD)
  const resultKey = Object.keys(json.result).find(k => k !== "last");
  if (!resultKey) return null;

  const rows = json.result[resultKey] as number[][];
  // Kraken format: [time(s), open, high, low, close, vwap, volume, count]
  // Convert to Binance format: [openTimeMs, open, high, low, close, ...]
  return rows.slice(-limit).map((r) => [
    r[0] * 1000, // open time in ms
    String(r[1]), // open
    String(r[2]), // high
    String(r[3]), // low
    String(r[4]), // close
    String(r[6]), // volume
  ]);
}

async function fetchBybit(symbol: string, limit: number): Promise<unknown[] | null> {
  const pair = BYBIT_PAIRS[symbol];
  if (!pair) return null;

  const url = `https://api.bybit.com/v5/market/kline?category=spot&symbol=${pair}&interval=1&limit=${limit}`;

  const resp = await fetch(url, { signal: AbortSignal.timeout(8_000) });
  if (!resp.ok) return null;

  const json = await resp.json() as { retCode: number; result: { list: string[][] } };
  if (json.retCode !== 0) return null;

  // Bybit format: [startTime(ms), open, high, low, close, volume, turnover] (newest first)
  const rows = json.result.list.reverse(); // oldest first
  return rows.map((r) => [
    parseInt(r[0]), // open time in ms
    r[1], // open
    r[2], // high
    r[3], // low
    r[4], // close
    r[5], // volume
  ]);
}

router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = (req.params.symbol || "BTCUSDT").toUpperCase();
  const limit = Math.min(parseInt((req.query.limit as string) || "300", 10), 720);

  // Try Kraken first, then Bybit
  for (const [name, fetcher] of [
    ["Kraken", () => fetchKraken(symbol, limit)],
    ["Bybit",  () => fetchBybit(symbol, limit)],
  ] as [string, () => Promise<unknown[] | null>][]) {
    try {
      const data = await fetcher();
      if (data && data.length > 0) {
        res.set("Cache-Control", "public, max-age=10");
        res.json(data);
        return;
      }
    } catch (err) {
      console.warn(`[Klines] ${name} failed for ${symbol}:`, err);
    }
  }

  res.status(502).json({ error: "All klines sources failed" });
});

export default router;
