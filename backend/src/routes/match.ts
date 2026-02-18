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
import { config } from "../config";

const router = Router();

/** GET /api/match/active/list — Get all active matches (for live feed). */
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

/** GET /api/match/active/:address — Get a player's current active match. */
router.get("/active/:address", async (req, res) => {
  const { address } = req.params;

  const [snap1, snap2] = await Promise.all([
    matchesRef.orderByChild("player1").equalTo(address).once("value"),
    matchesRef.orderByChild("player2").equalTo(address).once("value"),
  ]);

  let foundId: string | null = null;
  let foundData: Record<string, unknown> | null = null;

  for (const snap of [snap1, snap2]) {
    if (snap.exists()) {
      snap.forEach((child) => {
        const m = child.val();
        if (m.status === "active" && !foundId) {
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

  // Stale check: if match is 5 min past endTime, return null.
  const now = Date.now();
  const endTime = m.endTime as number | undefined;
  if (endTime && now > endTime + 5 * 60 * 1000) {
    res.json({ match: null });
    return;
  }

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
    },
  });
});

/** GET /api/match/history/:address — Get match history for a user (enriched). */
router.get("/history/:address", async (req, res) => {
  const { address } = req.params;

  const [snap1, snap2] = await Promise.all([
    matchesRef.orderByChild("player1").equalTo(address).once("value"),
    matchesRef.orderByChild("player2").equalTo(address).once("value"),
  ]);

  const rawMatches: Array<Record<string, unknown> & { id: string }> = [];
  const seen = new Set<string>();
  const settledStatuses = new Set(["completed", "tied", "forfeited"]);

  for (const snap of [snap1, snap2]) {
    if (snap.exists()) {
      snap.forEach((child) => {
        const m = child.val();
        if (!seen.has(child.key!) && settledStatuses.has(m.status)) {
          seen.add(child.key!);
          rawMatches.push({ id: child.key!, ...m });
        }
      });
    }
  }

  rawMatches.sort((a, b) => ((b.settledAt as number) || 0) - ((a.settledAt as number) || 0));

  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const start = (page - 1) * limit;
  const pageMatches = rawMatches.slice(start, start + limit);

  // Batch-fetch opponent gamer tags.
  const opponentAddresses = pageMatches.map((m) =>
    m.player1 === address ? (m.player2 as string) : (m.player1 as string)
  );
  const uniqueOpponents = [...new Set(opponentAddresses)];
  const opponentUsers = await Promise.all(uniqueOpponents.map((a) => getUser(a)));
  const tagMap = new Map<string, string>();
  uniqueOpponents.forEach((a, i) => {
    tagMap.set(a, opponentUsers[i]?.gamerTag || a.slice(0, 8));
  });

  // Enrich each match with result, PnL, and opponent info.
  const rake = config.rakePercent;
  const enriched = pageMatches.map((m) => {
    const oppAddr = m.player1 === address ? (m.player2 as string) : (m.player1 as string);
    const betAmount = (m.betAmount as number) || 0;

    let result: "WIN" | "LOSS" | "TIE";
    let pnl: number;

    if (m.status === "tied") {
      result = "TIE";
      pnl = 0;
    } else if (m.winner === address) {
      result = "WIN";
      pnl = betAmount * (1 - rake); // net winnings after rake
    } else {
      result = "LOSS";
      pnl = -betAmount;
    }

    return {
      id: m.id,
      opponentAddress: oppAddr,
      opponentGamerTag: tagMap.get(oppAddr) || oppAddr.slice(0, 8),
      duration: m.duration as string,
      betAmount,
      result,
      pnl,
      settledAt: m.settledAt as number,
    };
  });

  res.json({
    matches: enriched,
    total: rawMatches.length,
    page,
    limit,
  });
});

/** GET /api/match/profile/:address — Check if player has an on-chain profile. */
router.get("/profile/:address", async (req, res) => {
  // Keep this endpoint for profile creation flow during onboarding.
  const { address } = req.params;
  try {
    const { playerProfileExists, getPlayerProfilePDA } = await import("../utils/solana");
    const { PublicKey } = await import("@solana/web3.js");
    const { config } = await import("../config");

    const exists = await playerProfileExists(address);
    const [profilePda] = getPlayerProfilePDA(new PublicKey(address));

    res.json({
      exists,
      profilePda: profilePda.toBase58(),
      programId: config.programId,
    });
  } catch (err) {
    console.error(`[Match] Profile check error for ${address}:`, err);
    res.status(500).json({ error: "Failed to check profile" });
  }
});

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

/** GET /api/match/:id/positions — Get positions for a match. */
router.get("/:id/positions", requireAuth, async (req: AuthRequest, res) => {
  const positions = await getPositions(req.params.id, req.userAddress!);
  res.json({ positions });
});

/** POST /api/match/:id/trade — Submit a trade (open position). */
router.post(
  "/:id/trade",
  requireAuth,
  async (req: AuthRequest, res) => {
    const { asset, isLong, size, leverage } = req.body;
    const matchId = req.params.id;

    // ── Input validation (mirrors WS handler checks) ──
    const DEMO_BALANCE = 1_000_000;
    const validAssets = ["BTC", "ETH", "SOL"];

    if (!validAssets.includes(asset)) {
      res.status(400).json({ error: "Unknown asset" });
      return;
    }
    if (typeof isLong !== "boolean") {
      res.status(400).json({ error: "isLong must be a boolean" });
      return;
    }
    if (typeof size !== "number" || !Number.isFinite(size) || size < 1 || size > DEMO_BALANCE) {
      res.status(400).json({ error: "Invalid position size (1 – $1M)" });
      return;
    }
    if (typeof leverage !== "number" || !Number.isFinite(leverage) || leverage < 1 || leverage > 100) {
      res.status(400).json({ error: "Invalid leverage (1x – 100x)" });
      return;
    }

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

    // ── Demo balance check ──
    const openPositions = await getPositions(matchId, req.userAddress!);
    const usedMargin = openPositions
      .filter((p) => !p.closedAt)
      .reduce((sum, p) => sum + p.size, 0);
    if (size > DEMO_BALANCE - usedMargin) {
      res.status(400).json({ error: "Insufficient demo balance" });
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
      res.status(400).json({ error: "Price unavailable" });
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

export default router;
