import dotenv from "dotenv";
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  corsOrigins: (process.env.CORS_ORIGIN || "https://www.solfight.io")
    .split(",")
    .map((s) => s.trim()),

  // Firebase
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT || null,
  firebaseDatabaseUrl:
    process.env.FIREBASE_DATABASE_URL || "https://solfight-6e7d2-default-rtdb.firebaseio.com",

  // Solana — defaults match frontend (mainnet) so deposits work out of the box.
  solanaRpcUrl:
    process.env.SOLANA_RPC_URL || "https://mainnet.helius-rpc.com/?api-key=3ed6e181-117d-475f-9e54-2cd48e3f19a0",
  solanaWsUrl:
    process.env.SOLANA_WS_URL || "wss://mainnet.helius-rpc.com/?api-key=3ed6e181-117d-475f-9e54-2cd48e3f19a0",
  authorityKeypair: (() => {
    if (!process.env.AUTHORITY_KEYPAIR) return null;
    try {
      return JSON.parse(process.env.AUTHORITY_KEYPAIR);
    } catch {
      console.error("[Config] AUTHORITY_KEYPAIR is not valid JSON — ignoring");
      return null;
    }
  })(),
  usdcMint:
    process.env.USDC_MINT || "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",

  // Auth — JWT_SECRET must be set in production (no insecure fallback).
  jwtSecret: process.env.JWT_SECRET || "",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",

  // Demo trading
  demoInitialBalance: 1_000_000,
  tieTolerance: 0.00001, // 0.001% ROI tolerance for tie detection

  // On-chain escrow
  treasuryAddress:
    process.env.TREASURY_ADDRESS || "",
  rakePercent: 0.10, // 10% rake (informational; enforced on-chain via fee_bps=1000)
  adminAddress: process.env.ADMIN_ADDRESS || process.env.TREASURY_ADDRESS || "",

  // ── Service intervals ──
  matchmakingIntervalMs: 500,
  settlementIntervalMs: 1_000,
  priceBroadcastIntervalMs: 1_000,
  opponentBroadcastIntervalMs: 1_000,
  priceStalenessThresholdMs: 10_000,
  priceStalenessCheckIntervalMs: 5_000,

  // ── WebSocket ──
  wsForfeitGraceMs: 60_000,
  wsAuthTimeoutMs: 5_000,
  wsMaxConnectionsPerUser: 5,
  wsRateLimitMax: 30,
  wsRateLimitWindowMs: 10_000,
  wsMaxMessageBytes: 4_096,
  wsPingIntervalMs: 30_000,
  wsPongTimeoutMs: 10_000,

  // ── Trading ──
  priceMaxAgeMs: 30_000,
  maxLeverage: 100,
  validAssets: ["BTC", "ETH", "SOL"] as readonly string[],
  chatMaxLength: 200,
  liquidationThreshold: 1.0, // 100% of margin lost

  // ── Challenge ──
  challengeExpiryMs: 5 * 60 * 1000,
} as const;
