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

/**
 * Fetch prices from CoinGecko (server-side — no CORS issues).
 * Pyth integration can be added as primary source.
 */
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

/**
 * Fetch prices from Binance as fallback.
 */
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

/**
 * Start the price oracle loop — fetches every 3 seconds,
 * broadcasts every 1 second to active match rooms.
 */
export function startPriceOracle(): void {
  // Fetch prices every 3 seconds.
  setInterval(async () => {
    const prices =
      (await fetchPricesFromCoinGecko()) ??
      (await fetchPricesFromBinance());

    if (prices) {
      latestPrices = prices;
    }
  }, 3000);

  // Broadcast to all active match rooms every 1 second.
  setInterval(() => {
    broadcastToMatch("__all_active__", {
      type: "price_update",
      ...latestPrices,
    });
  }, 1000);

  console.log("[PriceOracle] Started — fetching every 3s, broadcasting every 1s");
}

/**
 * Snapshot prices for a specific match (called at match start/end).
 */
export function snapshotPrices(): PriceData {
  return { ...latestPrices };
}
