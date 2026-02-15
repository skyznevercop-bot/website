import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import {
  getMatch,
  getPositions,
  createPosition,
  matchesRef,
  getUser,
} from "../services/firebase";
import { getLatestPrices } from "../services/price-oracle";
import { confirmDeposit } from "../services/escrow";
import {
  getGamePdaAndEscrow,
  getPlatformPDA,
  fetchGameAccount,
  GameStatus,
} from "../utils/solana";
import { config } from "../config";

const router = Router();

/** GET /api/match/:id — Get match details. */
router.get("/:id", async (req, res) => {
  const match = await getMatch(req.params.id);

  if (!match) {
    res.status(404).json({ error: "Match not found" });
    return;
  }

  const [p1, p2] = await Promise.all([
    getUser(match.player1),
    getUser(match.player2),
  ]);

  res.json({
    id: req.params.id,
    ...match,
    player1Info: { address: match.player1, gamerTag: p1?.gamerTag },
    player2Info: { address: match.player2, gamerTag: p2?.gamerTag },
  });
});

/** GET /api/match/active/list — Get all active matches. */
router.get("/active/list", async (_req, res) => {
  const snap = await matchesRef
    .orderByChild("status")
    .equalTo("active")
    .limitToLast(20)
    .once("value");

  const matches: Array<Record<string, unknown>> = [];
  if (snap.exists()) {
    snap.forEach((child) => {
      matches.push({ id: child.key, ...child.val() });
    });
  }

  res.json({ matches });
});

/** GET /api/match/active/:address — Get a player's active (or awaiting_deposits) match. */
router.get("/active/:address", async (req, res) => {
  const { address } = req.params;

  // Firebase doesn't support OR queries, so query player1 and player2 separately.
  const [snap1, snap2] = await Promise.all([
    matchesRef.orderByChild("player1").equalTo(address).once("value"),
    matchesRef.orderByChild("player2").equalTo(address).once("value"),
  ]);

  const activeStatuses = new Set(["active", "awaiting_deposits"]);
  let foundId: string | null = null;
  let foundData: Record<string, unknown> | null = null;

  for (const snap of [snap1, snap2]) {
    if (snap.exists()) {
      snap.forEach((child) => {
        const m = child.val();
        if (activeStatuses.has(m.status) && !foundId) {
          foundId = child.key!;
          foundData = m;
        }
      });
    }
    if (foundId) break;
  }

  if (!foundId || !foundData) {
    res.json({ match: null });
    return;
  }

  const m = foundData as Record<string, unknown>;
  const isPlayer1 = m.player1 === address;
  const oppAddress = isPlayer1 ? m.player2 as string : m.player1 as string;
  const oppUser = await getUser(oppAddress);

  res.json({
    match: {
      matchId: foundId,
      status: m.status,
      duration: m.duration,
      betAmount: m.betAmount,
      startTime: m.startTime,
      endTime: m.endTime,
      opponentAddress: oppAddress,
      opponentGamerTag: oppUser?.gamerTag || oppAddress.slice(0, 8),
      onChainGameId: m.onChainGameId,
    },
  });
});

/** POST /api/match/:id/confirm-deposit — Confirm a USDC deposit for a match. */
router.post(
  "/:id/confirm-deposit",
  requireAuth,
  async (req: AuthRequest, res) => {
    const { txSignature } = req.body;
    const matchId = req.params.id;

    if (!txSignature || typeof txSignature !== "string") {
      res.status(400).json({ error: "Missing txSignature" });
      return;
    }

    if (!req.userAddress) {
      res.status(401).json({ error: "Not authenticated" });
      return;
    }

    try {
      const result = await confirmDeposit(matchId, req.userAddress, txSignature);
      if (result.success) {
        res.json({
          success: true,
          message: result.message,
          matchActive: result.matchNowActive,
        });
      } else {
        res.status(400).json({ error: result.message });
      }
    } catch (err) {
      console.error(`[Match] Deposit confirmation error for ${matchId}:`, err);
      res.status(500).json({ error: "Internal error verifying deposit" });
    }
  }
);

/** POST /api/match/:id/trade — Submit a trade (open position). */
router.post(
  "/:id/trade",
  requireAuth,
  async (req: AuthRequest, res) => {
    const { asset, isLong, size, leverage } = req.body;
    const matchId = req.params.id;

    const match = await getMatch(matchId);

    if (!match || match.status !== "active") {
      res.status(400).json({ error: "Match not active" });
      return;
    }

    if (
      req.userAddress !== match.player1 &&
      req.userAddress !== match.player2
    ) {
      res.status(403).json({ error: "Not a player in this match" });
      return;
    }

    const prices = getLatestPrices();
    const priceMap: Record<string, number> = {
      BTC: prices.btc,
      ETH: prices.eth,
      SOL: prices.sol,
    };

    const entryPrice = priceMap[asset];
    if (!entryPrice) {
      res.status(400).json({ error: "Unknown asset" });
      return;
    }

    const positionId = await createPosition(matchId, {
      playerAddress: req.userAddress!,
      assetSymbol: asset,
      isLong,
      entryPrice,
      size,
      leverage,
      openedAt: Date.now(),
    });

    res.json({
      id: positionId,
      asset,
      isLong,
      entryPrice,
      size,
      leverage,
    });
  }
);

/** GET /api/match/:id/positions — Get positions for a match. */
router.get("/:id/positions", requireAuth, async (req: AuthRequest, res) => {
  const positions = await getPositions(req.params.id, req.userAddress!);
  res.json({ positions });
});

/** GET /api/match/history/:address — Get match history for a user. */
router.get("/history/:address", async (req, res) => {
  const { address } = req.params;

  const [snap1, snap2] = await Promise.all([
    matchesRef.orderByChild("player1").equalTo(address).once("value"),
    matchesRef.orderByChild("player2").equalTo(address).once("value"),
  ]);

  const matches: Array<Record<string, unknown>> = [];
  const seen = new Set<string>();

  for (const snap of [snap1, snap2]) {
    if (snap.exists()) {
      snap.forEach((child) => {
        const m = child.val();
        if (!seen.has(child.key!) && m.status === "completed") {
          seen.add(child.key!);
          matches.push({ id: child.key, ...m });
        }
      });
    }
  }

  matches.sort((a, b) => ((b.settledAt as number) || 0) - ((a.settledAt as number) || 0));

  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const start = (page - 1) * limit;

  res.json({
    matches: matches.slice(start, start + limit),
    total: matches.length,
    page,
    limit,
  });
});

/** GET /api/match/:id/claim-info — Get on-chain addresses needed to build a claim_winnings tx. */
router.get("/:id/claim-info", requireAuth, async (req: AuthRequest, res) => {
  const match = await getMatch(req.params.id);
  if (!match) {
    res.status(404).json({ error: "Match not found" });
    return;
  }

  if (!match.onChainGameId) {
    res.status(400).json({ error: "No on-chain game for this match" });
    return;
  }

  const game = await fetchGameAccount(BigInt(match.onChainGameId));
  if (!game) {
    res.status(400).json({ error: "On-chain game not found" });
    return;
  }

  // Only allow claiming for Settled or Forfeited games.
  if (game.status !== GameStatus.Settled && game.status !== GameStatus.Forfeited) {
    res.status(400).json({ error: "Game is not in a claimable state" });
    return;
  }

  const { gamePda, escrowTokenAccount } = await getGamePdaAndEscrow(
    BigInt(match.onChainGameId)
  );
  const [platformPda] = getPlatformPDA();

  res.json({
    programId: config.programId,
    gameId: match.onChainGameId,
    gamePda: gamePda.toBase58(),
    escrowTokenAccount: escrowTokenAccount.toBase58(),
    platformPda: platformPda.toBase58(),
    treasuryAddress: config.treasuryAddress,
    winner: game.winner?.toBase58() || null,
  });
});

export default router;
