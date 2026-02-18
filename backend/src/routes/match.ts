import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import {
  getMatch,
  getPositions,
  createPosition,
  matchesRef,
  updateMatch,
  getUser,
} from "../services/firebase";
import { getLatestPrices } from "../services/price-oracle";
import { confirmDeposit, processMatchPayout } from "../services/escrow";
import {
  getGamePdaAndEscrow,
  getPlatformPDA,
  fetchGameAccount,
  GameStatus,
  playerProfileExists,
  getPlayerProfilePDA,
  endGameOnChain,
  getAuthorityKeypair,
} from "../utils/solana";
import { PublicKey } from "@solana/web3.js";
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

// Staleness thresholds for auto-cancellation.
const ACTIVE_STALE_MS = 5 * 60 * 1000;    // 5 min past endTime
const DEPOSIT_STALE_MS = 2 * 60 * 1000;   // 2 min past depositDeadline

/** Returns true if the match is stale and should be cancelled. */
function isStaleMatch(m: Record<string, unknown>): boolean {
  const now = Date.now();
  if (m.status === "active") {
    const endTime = m.endTime as number | undefined;
    return !!endTime && now > endTime + ACTIVE_STALE_MS;
  }
  if (m.status === "awaiting_deposits") {
    const deadline = m.depositDeadline as number | undefined;
    return !!deadline && now > deadline + DEPOSIT_STALE_MS;
  }
  return false;
}

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

  // If the match looks stale (settlement failed / timed out), return null
  // so the client doesn't get stuck on a broken match. Don't modify the
  // match status here — the settlement retry loop and deposit timeout loop
  // handle cleanup properly (including on-chain refunds).
  if (isStaleMatch(m)) {
    console.log(
      `[Match] Stale match ${foundId} (status=${m.status}, ` +
        `endTime=${m.endTime}, depositDeadline=${m.depositDeadline}) — returning null, letting background loops handle cleanup`
    );
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

/** GET /api/match/profile/:address — Check if player has an on-chain profile. */
router.get("/profile/:address", async (req, res) => {
  const { address } = req.params;

  try {
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

/**
 * POST /api/match/:id/retry-settlement — Admin: manually re-trigger on-chain
 * settlement for a stuck match (tied/completed/forfeited with onChainSettled=false).
 *
 * Auth: caller must be the platform authority (their JWT address must match).
 */
router.post(
  "/:id/retry-settlement",
  requireAuth,
  async (req: AuthRequest, res) => {
    // Only the platform authority may call this.
    const authorityPubkey = getAuthorityKeypair().publicKey.toBase58();
    if (req.userAddress !== authorityPubkey) {
      res.status(403).json({ error: "Authority only" });
      return;
    }

    const matchId = req.params.id;
    const match = await getMatch(matchId);
    if (!match) {
      res.status(404).json({ error: "Match not found" });
      return;
    }

    const settledStatuses = ["tied", "completed", "forfeited"];
    if (!settledStatuses.includes(match.status)) {
      res.status(400).json({
        error: `Match is '${match.status}', not in a settled state`,
      });
      return;
    }

    if (match.onChainSettled) {
      res.status(400).json({
        error: "Match is already marked onChainSettled=true",
        hint: "If payout is still stuck, check processMatchPayout manually.",
      });
      return;
    }

    if (!match.onChainGameId) {
      res.status(400).json({ error: "No onChainGameId for this match" });
      return;
    }

    // Check player profiles.
    const [p1HasProfile, p2HasProfile] = await Promise.all([
      playerProfileExists(match.player1),
      playerProfileExists(match.player2),
    ]);

    if (!p1HasProfile || !p2HasProfile) {
      const missing = [
        !p1HasProfile ? match.player1 : null,
        !p2HasProfile ? match.player2 : null,
      ].filter(Boolean);

      res.status(422).json({
        error: "Missing on-chain player profile(s) — cannot call end_game",
        missingProfiles: missing,
        hint:
          "The affected player(s) must visit the app and complete profile " +
          "creation before settlement can proceed. The retry loop will " +
          "automatically detect this and settle the match once profiles exist.",
      });
      return;
    }

    // Check current on-chain game status.
    const onChainGame = await fetchGameAccount(BigInt(match.onChainGameId));
    if (!onChainGame) {
      res.status(400).json({ error: "On-chain game account not found" });
      return;
    }

    const statusLabel: Record<number, string> = {
      [GameStatus.Active]: "Active",
      [GameStatus.Settled]: "Settled",
      [GameStatus.Tied]: "Tied",
      [GameStatus.Forfeited]: "Forfeited",
      [GameStatus.Cancelled]: "Cancelled",
      [GameStatus.Pending]: "Pending",
    };

    if (onChainGame.status !== GameStatus.Active) {
      // Already settled — just sync Firebase and trigger payout.
      console.log(
        `[Admin] Match ${matchId} already on-chain status=${statusLabel[onChainGame.status]} — syncing`
      );
      await updateMatch(matchId, { onChainSettled: true });
      try {
        await processMatchPayout(matchId, match);
      } catch (err) {
        res.status(500).json({
          error: "Firebase synced but payout failed",
          detail: String(err),
        });
        return;
      }
      res.json({
        success: true,
        action: "synced",
        onChainStatus: statusLabel[onChainGame.status],
      });
      return;
    }

    // Game is Active — call end_game.
    try {
      const isForfeit = match.status === "forfeited";
      const p1PnlBps = Math.round((match.player1Roi || 0) * 10000);
      const p2PnlBps = Math.round((match.player2Roi || 0) * 10000);

      const sig = await endGameOnChain(
        match.onChainGameId,
        match.winner || null,
        p1PnlBps,
        p2PnlBps,
        isForfeit
      );

      await updateMatch(matchId, {
        onChainSettled: true,
        onChainRetries: (match.onChainRetries || 0) + 1,
      });

      console.log(`[Admin] end_game succeeded for match ${matchId} | sig: ${sig}`);

      await processMatchPayout(matchId, match);

      res.json({ success: true, action: "settled", signature: sig });
    } catch (err) {
      console.error(`[Admin] retry-settlement failed for match ${matchId}:`, err);
      res.status(500).json({
        error: "end_game transaction failed",
        detail: String(err),
      });
    }
  }
);

export default router;
