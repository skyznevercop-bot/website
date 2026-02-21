import express from "express";
import cors from "cors";
import helmet from "helmet";
import { createServer } from "http";
import { config } from "./config";
import { rateLimit } from "./middleware/rate-limit";
import { setupWebSocket } from "./ws/handler";
import { startMatchmakingLoop } from "./services/matchmaking";
import { startPriceOracle } from "./services/price-oracle";
import { startSettlementLoop } from "./services/settlement";


// Routes
import userRoutes from "./routes/user";
import queueRoutes from "./routes/queue";
import matchRoutes from "./routes/match";
import balanceRoutes from "./routes/balance";
import leaderboardRoutes from "./routes/leaderboard";
import referralRoutes from "./routes/referral";
import clanRoutes from "./routes/clan";
import rpcProxyRoutes from "./routes/rpc-proxy";
import klinesRoutes from "./routes/klines";
import friendsRoutes from "./routes/friends";
import challengeRoutes from "./routes/challenge";
import profileRoutes from "./routes/profile";

// ── Security: refuse to start without a proper JWT secret ──
if (!config.jwtSecret) {
  console.error("\n  ✖  FATAL: JWT_SECRET environment variable is not set.");
  console.error("  Set a strong random secret (e.g. 64+ hex chars) before starting the server.\n");
  process.exit(1);
}

const app = express();
const server = createServer(app);

// Trust the first proxy (Render / Vercel) so req.ip returns the real client IP.
app.set("trust proxy", 1);

// Middleware
app.use(helmet());  // Security headers (X-Content-Type-Options, X-Frame-Options, etc.)
app.use(cors({ origin: config.corsOrigin, credentials: true }));
app.use(express.json({ limit: "1mb" }));  // Prevent large-payload DoS
app.use(rateLimit(100, 60_000)); // 100 requests per minute

// Health check
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: Date.now() });
});

// API Routes
app.use("/api", userRoutes);
app.use("/api/queue", queueRoutes);
app.use("/api/match", matchRoutes);
app.use("/api", balanceRoutes);
app.use("/api/leaderboard", leaderboardRoutes);
app.use("/api/referral", referralRoutes);
app.use("/api/clan", clanRoutes);
app.use("/api/rpc-proxy", rpcProxyRoutes);
app.use("/api/klines", klinesRoutes);
app.use("/api/friends", friendsRoutes);
app.use("/api/challenge", challengeRoutes);
app.use("/api/profile", profileRoutes);

// WebSocket
setupWebSocket(server);

// Start background services
startMatchmakingLoop();       // 500ms — FIFO matching (instant, no on-chain)
startPriceOracle();           // SSE streaming + 1s broadcast
startSettlementLoop();        // 5s — check for ended matches

// Start server
server.listen(config.port, () => {
  console.log(`
  ┌─────────────────────────────────────────┐
  │         SolArena Backend v2             │
  │         "Deposit Once, Play Instantly"  │
  │                                         │
  │  REST API:  http://localhost:${config.port}      │
  │  WebSocket: ws://localhost:${config.port}/ws     │
  │                                         │
  │  Services:                              │
  │    ✓ Matchmaking (500ms FIFO, instant)  │
  │    ✓ Price Oracle (Pyth SSE + fallback) │
  │    ✓ Settlement (5s check, instant pay) │
  │    ✓ Firebase Realtime Database         │
  └─────────────────────────────────────────┘
  `);

  if (!config.authorityKeypair) {
    console.warn(
      `\n  ⚠️  WARNING: AUTHORITY_KEYPAIR not set — withdrawals will fail!\n`
    );
  }
});

export { app, server };
