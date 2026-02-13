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

export default router;
