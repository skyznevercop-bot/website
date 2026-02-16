import express from "express";
import cors from "cors";
import { createServer } from "http";
import { config } from "./config";
import { rateLimit } from "./middleware/rate-limit";
import { setupWebSocket } from "./ws/handler";
import { startMatchmakingLoop } from "./services/matchmaking";
import { startPriceOracle } from "./services/price-oracle";
import { startSettlementLoop, startOnChainRetryLoop } from "./services/settlement";
import { startDepositTimeoutLoop } from "./services/escrow";

// Routes
import userRoutes from "./routes/user";
import queueRoutes from "./routes/queue";
import matchRoutes from "./routes/match";
import leaderboardRoutes from "./routes/leaderboard";
import portfolioRoutes from "./routes/portfolio";
import referralRoutes from "./routes/referral";
import clanRoutes from "./routes/clan";
import rpcProxyRoutes from "./routes/rpc-proxy";

const app = express();
const server = createServer(app);

// Middleware
app.use(cors({ origin: config.corsOrigin, credentials: true }));
app.use(express.json());
app.use(rateLimit(100, 60_000)); // 100 requests per minute

// Health check
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: Date.now() });
});

// API Routes
app.use("/api", userRoutes);
app.use("/api/queue", queueRoutes);
app.use("/api/match", matchRoutes);
app.use("/api/leaderboard", leaderboardRoutes);
app.use("/api/portfolio", portfolioRoutes);
app.use("/api/referral", referralRoutes);
app.use("/api/clan", clanRoutes);
app.use("/api/rpc-proxy", rpcProxyRoutes);

// WebSocket
setupWebSocket(server);

// Start background services
startMatchmakingLoop();
startPriceOracle();
startSettlementLoop();
startOnChainRetryLoop();
startDepositTimeoutLoop();

// Start server
server.listen(config.port, () => {
  console.log(`
  ┌─────────────────────────────────────────┐
  │           SolFight Backend              │
  │                                         │
  │  REST API:  http://localhost:${config.port}      │
  │  WebSocket: ws://localhost:${config.port}/ws     │
  │                                         │
  │  Services:                              │
  │    ✓ Matchmaking (500ms FIFO)           │
  │    ✓ Price Oracle (3s fetch, 1s push)   │
  │    ✓ Settlement (5s check)              │
  │    ✓ On-chain Retry (30s)               │
  │    ✓ Escrow Deposit Monitor (5s)        │
  │    ✓ Firebase Realtime Database         │
  └─────────────────────────────────────────┘
  `);

  if (!config.authorityKeypair) {
    console.warn(
      `\n  ⚠️  WARNING: AUTHORITY_KEYPAIR not set — escrow payouts will fail!\n`
    );
  }
});

export { app, server };
