import { EventSource } from "eventsource";
import { broadcastToMatch } from "../ws/rooms";

export interface PriceData {
  btc: number;
  eth: number;
  sol: number;
  timestamp: number;
}

let latestPrices: PriceData = {
  btc: 100000,
  eth: 2700,
  sol: 200,
  timestamp: Date.now(),
};

export function getLatestPrices(): PriceData {
  return { ...latestPrices };
}

// ── Pyth Hermes SSE Streaming (primary) ────────────────────────────────────

/** Pyth price feed IDs for BTC/USD, ETH/USD, SOL/USD. */
const PYTH_FEED_IDS: Record<string, keyof Omit<PriceData, "timestamp">> = {
  "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43": "btc",
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace": "eth",
  "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d": "sol",
};

const HERMES_BASE = "https://hermes.pyth.network";

let pythSource: EventSource | null = null;
let pythConnected = false;
let reconnectAttempts = 0;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let fallbackInterval: ReturnType<typeof setInterval> | null = null;
/** Suppress repeated connect logs after the first. */
let loggedFirstUpdate = false;

function buildStreamUrl(): string {
  const ids = Object.keys(PYTH_FEED_IDS);
  const params = ids.map((id) => `ids[]=${id}`).join("&");
  return `${HERMES_BASE}/v2/updates/price/stream?${params}&parsed=true&allow_unordered=true&benchmarks_only=false`;
}

function connectPythStream(): void {
  // Clean up previous connection.
  if (pythSource) {
    pythSource.close();
    pythSource = null;
  }

  const url = buildStreamUrl();
  const es = new EventSource(url);
  pythSource = es;

  es.onopen = () => {
    pythConnected = true;
    reconnectAttempts = 0;
    console.log("[PriceOracle] Pyth Hermes SSE connected");

    // Stop fallback polling — Pyth is live.
    stopFallbackPolling();
  };

  es.onmessage = (event: MessageEvent) => {
    try {
      const data = JSON.parse(event.data as string);
      const parsed = data.parsed as Array<{
        id: string;
        price: { price: string; expo: number; publish_time: number };
        ema_price: { price: string; expo: number };
      }> | undefined;

      if (!parsed || parsed.length === 0) return;

      let updated = false;
      for (const feed of parsed) {
        // Feed IDs come without the 0x prefix in responses.
        const feedId = feed.id.startsWith("0x") ? feed.id : `0x${feed.id}`;
        const key = PYTH_FEED_IDS[feedId];
        if (!key) continue;

        const rawPrice = parseInt(feed.price.price, 10);
        const expo = feed.price.expo;
        const price = rawPrice * Math.pow(10, expo);

        if (price > 0) {
          latestPrices[key] = price;
          updated = true;
        }
      }

      if (updated) {
        latestPrices.timestamp = Date.now();

        if (!loggedFirstUpdate) {
          loggedFirstUpdate = true;
          console.log(
            `[PriceOracle] First Pyth prices: BTC=$${latestPrices.btc.toFixed(2)} ` +
            `ETH=$${latestPrices.eth.toFixed(2)} SOL=$${latestPrices.sol.toFixed(2)}`
          );
        }
      }
    } catch (err) {
      console.error("[PriceOracle] Pyth SSE parse error:", err);
    }
  };

  es.onerror = () => {
    pythConnected = false;
    es.close();
    pythSource = null;
    scheduleReconnect();
  };
}

function scheduleReconnect(): void {
  if (reconnectTimer) return; // already scheduled

  // Exponential backoff: 1s, 2s, 4s, 5s max (capped low to keep prices fresh).
  const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 5_000);
  reconnectAttempts++;

  console.log(
    `[PriceOracle] Pyth SSE disconnected — reconnecting in ${delay / 1000}s (attempt #${reconnectAttempts})`
  );

  // Start fallback polling while SSE is down.
  startFallbackPolling();

  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectPythStream();
  }, delay);
}

// ── CoinGecko / Binance Fallback ───────────────────────────────────────────

async function fetchPricesFromCoinGecko(): Promise<PriceData | null> {
  try {
    const response = await fetch(
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd"
    );
    if (!response.ok) return null;
    const data = (await response.json()) as Record<string, Record<string, number>>;
    return {
      btc: data.bitcoin?.usd ?? latestPrices.btc,
      eth: data.ethereum?.usd ?? latestPrices.eth,
      sol: data.solana?.usd ?? latestPrices.sol,
      timestamp: Date.now(),
    };
  } catch {
    return null;
  }
}

async function fetchPricesFromBinance(): Promise<PriceData | null> {
  try {
    const symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
    const results = await Promise.all(
      symbols.map(async (s) => {
        const res = await fetch(
          `https://api.binance.com/api/v3/ticker/price?symbol=${s}`
        );
        if (!res.ok) return null;
        return res.json();
      })
    );

    if (results.some((r) => r === null)) return null;

    const typed = results as Array<{ price: string }>;
    return {
      btc: parseFloat(typed[0].price),
      eth: parseFloat(typed[1].price),
      sol: parseFloat(typed[2].price),
      timestamp: Date.now(),
    };
  } catch {
    return null;
  }
}

function startFallbackPolling(): void {
  if (fallbackInterval) return; // already polling

  console.log("[PriceOracle] Fallback polling active (CoinGecko/Binance every 3s)");

  // Fetch immediately, then every 3s.
  doFallbackFetch();
  fallbackInterval = setInterval(doFallbackFetch, 3000);
}

function stopFallbackPolling(): void {
  if (!fallbackInterval) return;
  clearInterval(fallbackInterval);
  fallbackInterval = null;
  console.log("[PriceOracle] Fallback polling stopped — Pyth SSE is live");
}

async function doFallbackFetch(): Promise<void> {
  const prices =
    (await fetchPricesFromCoinGecko()) ??
    (await fetchPricesFromBinance());
  if (prices) {
    latestPrices = prices;
  }
}

// ── Public API ─────────────────────────────────────────────────────────────

/**
 * Start the price oracle:
 *   1. Connect Pyth Hermes SSE for real-time streaming (primary).
 *   2. CoinGecko/Binance polling as fallback when SSE is down.
 *   3. Broadcast to all active match rooms every 1 second.
 */
export function startPriceOracle(): void {
  // Primary: Pyth Hermes SSE streaming.
  connectPythStream();

  // Broadcast to all active match rooms every 1 second.
  setInterval(() => {
    broadcastToMatch("__all_active__", {
      type: "price_update",
      ...latestPrices,
    });
  }, 1000);

  // Staleness watchdog: if SSE appears connected but prices are stale
  // (no updates for 10s), force fallback polling. This catches silent
  // SSE failures where the connection stays open but data stops flowing.
  setInterval(() => {
    const age = Date.now() - latestPrices.timestamp;
    if (age > 10_000) {
      if (pythConnected) {
        console.warn(
          `[PriceOracle] Prices stale (${(age / 1000).toFixed(1)}s) despite SSE "connected" — forcing reconnect + fallback`
        );
        // Force close and reconnect the SSE stream.
        pythConnected = false;
        if (pythSource) {
          pythSource.close();
          pythSource = null;
        }
        scheduleReconnect();
      } else if (!fallbackInterval) {
        // SSE is down and fallback somehow isn't running — start it.
        console.warn("[PriceOracle] Prices stale and no fallback running — starting fallback");
        startFallbackPolling();
      }
    }
  }, 5_000);

  console.log("[PriceOracle] Started — Pyth Hermes SSE (primary), CoinGecko/Binance (fallback), broadcasting every 1s");
}

/**
 * Snapshot prices for a specific match (called at match start/end).
 */
export function snapshotPrices(): PriceData {
  return { ...latestPrices };
}
