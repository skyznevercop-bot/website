import dotenv from "dotenv";
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  corsOrigin: process.env.CORS_ORIGIN || "http://localhost:8080",

  // Firebase
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT || null,
  firebaseDatabaseUrl:
    process.env.FIREBASE_DATABASE_URL || "https://solfight-6e7d2-default-rtdb.firebaseio.com",

  // Solana
  solanaRpcUrl:
    process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com",
  solanaWsUrl:
    process.env.SOLANA_WS_URL || "wss://api.devnet.solana.com",
  authorityKeypair: (() => {
    if (!process.env.AUTHORITY_KEYPAIR) return null;
    try {
      return JSON.parse(process.env.AUTHORITY_KEYPAIR);
    } catch {
      console.error("[Config] AUTHORITY_KEYPAIR is not valid JSON — ignoring");
      return null;
    }
  })(),
  programId: process.env.PROGRAM_ID || "268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8",
  usdcMint:
    process.env.USDC_MINT || "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",

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
  depositTimeoutMs: 300_000, // 5 minutes for both players to deposit
} as const;
