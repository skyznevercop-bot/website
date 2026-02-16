import { config } from "../config";
import {
  matchesRef,
  getMatch,
  getMatchesByStatus,
  getPositions,
  updatePosition,
  updateMatch,
  updateUser,
  getUser,
  DbPosition,
} from "./firebase";
import { getLatestPrices } from "./price-oracle";
import { broadcastToMatch } from "../ws/rooms";
import { processMatchPayout } from "./escrow";
import { endGameOnChain, fetchGameAccount, GameStatus, refundEscrowOnChain, playerProfileExists } from "../utils/solana";

const DEMO_BALANCE = config.demoInitialBalance;
const TIE_TOLERANCE = config.tieTolerance;

/**
 * Start the settlement loop — checks every 5 seconds for matches
 * past their end time that need to be settled.
 */
export function startSettlementLoop(): void {
  setInterval(async () => {
    try {
      const snap = await matchesRef
        .orderByChild("status")
        .equalTo("active")
        .once("value");

      if (!snap.exists()) return;

      const now = Date.now();

      snap.forEach((child) => {
        const match = child.val();
        if (match.endTime && match.endTime <= now) {
          void settleMatch(child.key!, match);
        }
      });
    } catch (err) {
      console.error("[Settlement] Error:", err);
    }
  }, 5000);

  console.log("[Settlement] Started — checking every 5s");
}

/**
 * Settle a match via forfeit (player disconnected).
 */
export async function settleByForfeit(
  matchId: string,
  disconnectedPlayer: string
): Promise<void> {
  const snap = await matchesRef.child(matchId).once("value");
  if (!snap.exists()) return;

  const match = snap.val();
  if (match.status !== "active") return;

  const winner =
    disconnectedPlayer === match.player1 ? match.player2 : match.player1;

  // ── Step 1: Update Firebase + broadcast IMMEDIATELY ──
  await updateMatch(matchId, {
    status: "forfeited",
    winner,
    player1Roi: 0,
    player2Roi: 0,
    settledAt: Date.now(),
    onChainSettled: false,
  });

  await updatePlayerStats(match.player1, match.player2, winner, match.betAmount, false);

  broadcastToMatch(matchId, {
    type: "match_end",
    matchId,
    winner,
    p1Roi: 0,
    p2Roi: 0,
    isForfeit: true,
    isTie: false,
  });

  console.log(
    `[Settlement] Match ${matchId} forfeited | ${disconnectedPlayer} disconnected | Winner: ${winner}`
  );

  // ── Step 2: Settle on-chain asynchronously (retry loop picks up failures) ──
  if (match.onChainGameId) {
    settleOnChainAsync(matchId, match.onChainGameId, winner, 0, 0);
  }
}

/**
 * Settle a single match: calculate ROI, determine winner, broadcast
 * result immediately, then settle on-chain asynchronously.
 */
async function settleMatch(
  matchId: string,
  match: Record<string, unknown>
): Promise<void> {
  const prices = getLatestPrices();
  const priceMap: Record<string, number> = {
    BTC: prices.btc,
    ETH: prices.eth,
    SOL: prices.sol,
  };

  const allPositions = await getPositions(matchId);

  // Close any open positions at current prices.
  for (const pos of allPositions) {
    if (!pos.closedAt) {
      const currentPrice = priceMap[pos.assetSymbol] || pos.entryPrice;
      const pnl = calculatePnl(pos, currentPrice);

      await updatePosition(matchId, pos.id, {
        exitPrice: currentPrice,
        pnl,
        closedAt: Date.now(),
        closeReason: "match_end",
      });

      pos.exitPrice = currentPrice;
      pos.pnl = pnl;
      pos.closedAt = Date.now();
    }
  }

  const player1 = match.player1 as string;
  const player2 = match.player2 as string;
  const betAmount = match.betAmount as number;
  const onChainGameId = match.onChainGameId as number | undefined;

  const p1Pnl = allPositions
    .filter((p) => p.playerAddress === player1)
    .reduce((sum, p) => sum + (p.pnl || 0), 0);

  const p2Pnl = allPositions
    .filter((p) => p.playerAddress === player2)
    .reduce((sum, p) => sum + (p.pnl || 0), 0);

  const p1Roi = p1Pnl / DEMO_BALANCE;
  const p2Roi = p2Pnl / DEMO_BALANCE;

  const isTie = Math.abs(p1Roi - p2Roi) <= TIE_TOLERANCE;
  let winner: string | undefined;
  let status: "completed" | "tied";

  if (isTie) {
    status = "tied";
  } else {
    status = "completed";
    winner = p1Roi > p2Roi ? player1 : player2;
  }

  // ── Step 1: Update Firebase + broadcast result IMMEDIATELY ──
  // Users see the result right away, regardless of on-chain outcome.
  await updateMatch(matchId, {
    status,
    winner,
    player1Roi: p1Roi,
    player2Roi: p2Roi,
    settledAt: Date.now(),
    onChainSettled: false,
  });

  await updatePlayerStats(player1, player2, winner, betAmount, isTie);

  broadcastToMatch(matchId, {
    type: "match_end",
    matchId,
    winner: winner || null,
    p1Roi: Math.round(p1Roi * 10000) / 100,
    p2Roi: Math.round(p2Roi * 10000) / 100,
    isTie,
    isForfeit: false,
  });

  console.log(
    `[Settlement] Match ${matchId} settled | ${isTie ? "TIE" : `Winner: ${winner}`} | ROI: ${(p1Roi * 100).toFixed(2)}% vs ${(p2Roi * 100).toFixed(2)}%`
  );

  // ── Step 2: Settle on-chain asynchronously (don't block the result) ──
  if (onChainGameId) {
    settleOnChainAsync(matchId, onChainGameId, winner, p1Roi, p2Roi);
  }
}

/**
 * Settle on-chain in the background with a timeout.
 * If it fails, the retry loop will pick it up later.
 */
function settleOnChainAsync(
  matchId: string,
  onChainGameId: number,
  winner: string | undefined | null,
  p1Roi: number,
  p2Roi: number
): void {
  const TIMEOUT_MS = 15_000; // 15-second timeout

  const onChainPromise = (async () => {
    const p1PnlBps = Math.round(p1Roi * 10000);
    const p2PnlBps = Math.round(p2Roi * 10000);
    await endGameOnChain(
      onChainGameId,
      winner || null,
      p1PnlBps,
      p2PnlBps,
      false
    );
  })();

  const timeoutPromise = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error("On-chain settlement timed out")), TIMEOUT_MS)
  );

  Promise.race([onChainPromise, timeoutPromise])
    .then(async () => {
      await updateMatch(matchId, { onChainSettled: true });
      console.log(`[Settlement] On-chain settled for match ${matchId}`);

      const updatedMatch = await getMatch(matchId);
      if (updatedMatch) {
        processMatchPayout(matchId, updatedMatch).catch((err) => {
          console.error(`[Settlement] Payout failed for match ${matchId}:`, err);
        });
      }
    })
    .catch((err) => {
      console.error(`[Settlement] On-chain end_game failed for match ${matchId}:`, err);
      console.warn(`[Settlement] Retry loop will pick up match ${matchId}`);
    });
}

function calculatePnl(pos: DbPosition, currentPrice: number): number {
  const exitPrice = pos.exitPrice ?? currentPrice;
  const priceDiff = pos.isLong
    ? exitPrice - pos.entryPrice
    : pos.entryPrice - exitPrice;
  return (priceDiff / pos.entryPrice) * pos.size * pos.leverage;
}

/**
 * Retry loop for matches that settled in Firebase but failed on-chain,
 * and for matches whose refund failed after on-chain settlement.
 * Runs every 30 seconds.
 */
export function startOnChainRetryLoop(): void {
  setInterval(async () => {
    try {
      // ── Part 1: Retry on-chain settlement for unsettled matches ──
      for (const status of ["completed", "tied", "forfeited"] as const) {
        const matches = await getMatchesByStatus(status);
        for (const { id, data: match } of matches) {
          if (match.onChainSettled) continue;
          if (!match.onChainGameId) continue;
          // Don't retry too frequently — skip if settled less than 30s ago.
          if (match.settledAt && Date.now() - match.settledAt < 30_000) continue;

          try {
            // Check on-chain status FIRST to avoid calling end_game on
            // a game that was already settled (would fail with GameNotActive).
            const onChainGame = await fetchGameAccount(BigInt(match.onChainGameId));

            if (onChainGame && onChainGame.status !== GameStatus.Active) {
              // Already settled on-chain — just mark Firebase and trigger payout.
              console.log(`[Settlement] Match ${id} already settled on-chain (status=${onChainGame.status}) — syncing Firebase`);
              await updateMatch(id, { onChainSettled: true });

              const updatedMatch = await getMatch(id);
              if (updatedMatch) {
                processMatchPayout(id, updatedMatch).catch((err) => {
                  console.error(`[Settlement] Payout failed for match ${id}:`, err);
                });
              }
              continue;
            }

            // Game is still Active on-chain — check if we CAN settle it.
            // end_game requires both player profile PDAs to exist.
            const p1HasProfile = await playerProfileExists(match.player1);
            const p2HasProfile = await playerProfileExists(match.player2);

            if (!p1HasProfile || !p2HasProfile) {
              // Can't settle — player profiles don't exist. Stop wasting SOL.
              const retries = (match.onChainRetries || 0) + 1;
              await updateMatch(id, { onChainRetries: retries });
              if (retries <= 1) {
                console.warn(
                  `[Settlement] Match ${id}: missing player profiles (p1=${p1HasProfile}, p2=${p2HasProfile}) — skipping on-chain retry`
                );
              }
              continue;
            }

            // Cap retries to avoid infinite SOL drain.
            const retries = match.onChainRetries || 0;
            if (retries >= 10) {
              if (retries === 10) {
                console.error(`[Settlement] Match ${id}: max retries (10) reached — giving up on-chain settlement`);
                await updateMatch(id, { onChainRetries: retries + 1 });
              }
              continue;
            }

            console.log(`[Settlement] Retrying on-chain settlement for match ${id} (${status}, attempt ${retries + 1})...`);

            const isForfeit = status === "forfeited";
            const p1PnlBps = Math.round((match.player1Roi || 0) * 10000);
            const p2PnlBps = Math.round((match.player2Roi || 0) * 10000);

            await endGameOnChain(
              match.onChainGameId,
              match.winner || null,
              p1PnlBps,
              p2PnlBps,
              isForfeit
            );

            await updateMatch(id, { onChainSettled: true, onChainRetries: retries + 1 });
            console.log(`[Settlement] On-chain retry succeeded for match ${id}`);

            const updatedMatch = await getMatch(id);
            if (updatedMatch) {
              processMatchPayout(id, updatedMatch).catch((err) => {
                console.error(`[Settlement] Payout failed on retry for match ${id}:`, err);
              });
            }
          } catch (err) {
            // Increment retry counter on failure.
            const retries = (match.onChainRetries || 0) + 1;
            await updateMatch(id, { onChainRetries: retries });
            console.error(`[Settlement] On-chain retry #${retries} failed for match ${id}:`, err);
          }
        }
      }

      // ── Part 2: Retry failed refunds (ties and cancelled matches) ──
      await retryFailedRefunds();
    } catch (err) {
      console.error("[Settlement] Retry loop error:", err);
    }
  }, 30_000);

  console.log("[Settlement] On-chain retry loop started (30s interval)");
}

/**
 * Retry refunds for tied/cancelled matches where the refund failed.
 * Picks up matches with escrowState === "refund_failed".
 */
async function retryFailedRefunds(): Promise<void> {
  for (const status of ["tied", "cancelled"] as const) {
    const matches = await getMatchesByStatus(status);
    for (const { id, data: match } of matches) {
      if (match.escrowState !== "refund_failed") continue;
      if (!match.onChainGameId) continue;

      console.log(`[Settlement] Retrying refund for match ${id} (${status})...`);

      try {
        const refundSig = await refundEscrowOnChain(
          match.onChainGameId,
          match.player1,
          match.player2
        );
        await updateMatch(id, {
          escrowState: "refunded",
          refundSignatures: { refund: refundSig },
        });

        broadcastToMatch(id, {
          type: "escrow_refunded",
          matchId: id,
          signature: refundSig,
        });

        console.log(`[Settlement] Refund retry succeeded for match ${id} | sig: ${refundSig}`);
      } catch (err) {
        console.error(`[Settlement] Refund retry still failing for match ${id}:`, err);
      }
    }
  }
}

async function updatePlayerStats(
  player1: string,
  player2: string,
  winner: string | undefined,
  betAmount: number,
  isTie: boolean
): Promise<void> {
  const [p1, p2] = await Promise.all([getUser(player1), getUser(player2)]);
  if (!p1 || !p2) return;

  if (isTie) {
    await Promise.all([
      updateUser(player1, {
        ties: (p1.ties || 0) + 1,
        gamesPlayed: (p1.gamesPlayed || 0) + 1,
        currentStreak: 0,
      }),
      updateUser(player2, {
        ties: (p2.ties || 0) + 1,
        gamesPlayed: (p2.gamesPlayed || 0) + 1,
        currentStreak: 0,
      }),
    ]);
  } else if (winner) {
    const loser = winner === player1 ? player2 : player1;
    const winnerStats = winner === player1 ? p1 : p2;
    const loserStats = winner === player1 ? p2 : p1;

    await Promise.all([
      updateUser(winner, {
        wins: (winnerStats.wins || 0) + 1,
        gamesPlayed: (winnerStats.gamesPlayed || 0) + 1,
        totalPnl:
          (winnerStats.totalPnl || 0) +
          betAmount * (2 * (1 - config.rakePercent) - 1),
        currentStreak: (winnerStats.currentStreak || 0) + 1,
      }),
      updateUser(loser, {
        losses: (loserStats.losses || 0) + 1,
        gamesPlayed: (loserStats.gamesPlayed || 0) + 1,
        totalPnl: (loserStats.totalPnl || 0) - betAmount,
        currentStreak: 0,
      }),
    ]);
  }
}
