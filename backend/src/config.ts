import dotenv from "dotenv";
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  corsOrigin: process.env.CORS_ORIGIN || "http://localhost:8080",

  // Database
  databaseUrl: process.env.DATABASE_URL!,

  // Redis
  redisUrl: process.env.REDIS_URL || "redis://localhost:6379",

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

  // Pyth price feed accounts (devnet)
  pythBtcUsd:
    process.env.PYTH_BTC_USD ||
    "GVXRSBjFk6e6J3NbVPXPvjQd1gKWgdI1IjZVDBvRV4tH",
  pythEthUsd:
    process.env.PYTH_ETH_USD ||
    "JBu1AL4obBcCMqKBBxhpWCNUt136ijcuMZLFvTP7iWdB",
  pythSolUsd:
    process.env.PYTH_SOL_USD ||
    "H6ARHf6YXhGYeQfUzQNGk6rDNnLBQKrenN712K4AQJEG",
} as const;
