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
  authorityKeypair: process.env.AUTHORITY_KEYPAIR
    ? JSON.parse(process.env.AUTHORITY_KEYPAIR)
    : null,
  programId: process.env.PROGRAM_ID || "So1F1gHTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  usdcMint:
    process.env.USDC_MINT || "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",

  // Auth
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",

  // Demo trading
  demoInitialBalance: 1_000_000,
  tieTolerance: 0.00001, // 0.001% ROI tolerance for tie detection

  // Escrow / Payout
  escrowWalletAddress:
    process.env.ESCROW_WALLET_ADDRESS ||
    "6ofVTNgoHbJGBtQB3xCDYXNayc8vczXu2Vob4bDBZtVc",
  rakePercent: 0.10, // 10% rake on winner's payout
  tieFeePercent: 0.02, // 2% total fee on ties (1% per player)
  depositTimeoutMs: 60_000, // 60 seconds for both players to deposit
  payoutRetryAttempts: 3,
  payoutRetryDelayMs: 2_000,
} as const;
