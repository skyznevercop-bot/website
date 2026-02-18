import { config } from "../config";
import {
  matchesRef,
  getPositions,
  updatePosition,
  updateMatch,
  updateUser,
  getUser,
  DbPosition,
} from "./firebase";
import { getLatestPrices } from "./price-oracle";
import { broadcastToMatch } from "../ws/rooms";
import { settleMatchBalances } from "./balance";

const DEMO_BALANCE = config.demoInitialBalance;
const TIE_TOLERANCE = config.tieTolerance;

/** Guard against concurrent settleMatch calls for the same matchId. */
const _settling = new Set<string>();

/**
 * Start the settlement loop — checks every 5 seconds for matches
 * past their end time that need to be settled.
 *
 * This is the ONLY background loop needed for settlement.
 * No more deposit recovery, on-chain retry, refund retry, or game closing loops.
 */
export function startSettlementLoop(): void {
  setInterval(async () => {
    try {
      // 1. Settle active matches that have ended.
      const activeSnap = await matchesRef
        .orderByChild("status")
        .equalTo("active")
        .once("value");

      if (activeSnap.exists()) {
        const now = Date.now();
        activeSnap.forEach((child) => {
          const match = child.val();
          if (match.endTime && match.endTime <= now) {
            void settleMatch(child.key!, match);
          }
        });
      }

      // 2. Recovery: retry balance settlement for matches that were
      //    marked completed/tied/forfeited but where balancesSettled is not true.
      //    This handles the case where the server crashed between updating
      //    the match status and completing the balance transfers.
      for (const status of ["completed", "tied", "forfeited"] as const) {
        const snap = await matchesRef
          .orderByChild("status")
          .equalTo(status)
          .once("value");

        if (!snap.exists()) continue;

        snap.forEach((child) => {
          const match = child.val();
          if (match.balancesSettled) return; // Already done.
          if (_settling.has(child.key!)) return; // Already in progress.

          console.warn(`[Settlement] Recovery: retrying balance settlement for ${child.key!} (status=${status})`);
          void retryBalanceSettlement(child.key!, match);
        });
      }
    } catch (err) {
      console.error("[Settlement] Error:", err);
    }
  }, 5000);

  console.log("[Settlement] Started — checking every 5s (with balance recovery)");
}

/**
 * Retry balance settlement for a match that was marked settled
 * but whose balances were not fully updated (crash recovery).
 */
async function retryBalanceSettlement(
  matchId: string,
  match: Record<string, unknown>
): Promise<void> {
  if (_settling.has(matchId)) return;
  _settling.add(matchId);
  try {
    const isTie = match.status === "tied";
    const winner = isTie ? undefined : (match.winner as string | undefined);

    await settleMatchBalances(
      matchId,
      winner,
      match.player1 as string,
      match.player2 as string,
      match.betAmount as number,
      isTie
    );

    await updateMatch(matchId, { balancesSettled: true });
    console.log(`[Settlement] Recovery complete for ${matchId}`);
  } catch (err) {
    console.error(`[Settlement] Recovery failed for ${matchId}:`, err);
  } finally {
    _settling.delete(matchId);
  }
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

  // 1. Update Firebase.
  await updateMatch(matchId, {
    status: "forfeited",
    winner,
    player1Roi: 0,
    player2Roi: 0,
    settledAt: Date.now(),
  });

  // 2. Settle balances instantly.
  await settleMatchBalances(
    matchId,
    winner,
    match.player1,
    match.player2,
    match.betAmount,
    false
  );
  await updateMatch(matchId, { balancesSettled: true });

  // 3. Update player stats.
  await updatePlayerStats(match.player1, match.player2, winner, match.betAmount, false);

  // 4. Broadcast result.
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
    `[Settlement] Match ${matchId} forfeited | ${disconnectedPlayer.slice(0, 8)}… disconnected | Winner: ${winner.slice(0, 8)}…`
  );
}

/**
 * Settle a single match: calculate ROI, determine winner, update balances instantly.
 */
async function settleMatch(
  matchId: string,
  match: Record<string, unknown>
): Promise<void> {
  if (_settling.has(matchId)) return;
  _settling.add(matchId);
  try {
    await _doSettleMatch(matchId, match);
  } finally {
    _settling.delete(matchId);
  }
}

async function _doSettleMatch(
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

  // 1. Update Firebase with result.
  await updateMatch(matchId, {
    status,
    winner,
    player1Roi: p1Roi,
    player2Roi: p2Roi,
    settledAt: Date.now(),
  });

  // 2. Settle balances INSTANTLY — no on-chain waiting.
  await settleMatchBalances(matchId, winner, player1, player2, betAmount, isTie);
  await updateMatch(matchId, { balancesSettled: true });

  // 3. Update player stats.
  await updatePlayerStats(player1, player2, winner, betAmount, isTie);

  // 4. Broadcast result immediately — users see it with zero delay.
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
    `[Settlement] Match ${matchId} settled | ${isTie ? "TIE" : `Winner: ${winner?.slice(0, 8)}…`} | ROI: ${(p1Roi * 100).toFixed(2)}% vs ${(p2Roi * 100).toFixed(2)}%`
  );
}

function calculatePnl(pos: DbPosition, currentPrice: number): number {
  const exitPrice = pos.exitPrice ?? currentPrice;
  const priceDiff = pos.isLong
    ? exitPrice - pos.entryPrice
    : pos.entryPrice - exitPrice;
  return (priceDiff / pos.entryPrice) * pos.size * pos.leverage;
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
