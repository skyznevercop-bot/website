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
import { broadcastToMatch, broadcastToAll, isUserConnected, getMatchLastPrices, clearMatchPrices } from "../ws/rooms";
import { settleMatchBalances } from "./balance";
import { expireStaleChallenges } from "../routes/challenge";
import { checkAndAwardAchievements, type MatchContext } from "./achievements";

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
      // 3. Expire stale friend challenges (unfreeze bets).
      await expireStaleChallenges();
    } catch (err) {
      console.error("[Settlement] Error:", err);
    }
  }, 5000);

  console.log("[Settlement] Started — checking every 5s (with balance recovery + challenge expiry)");
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
  // Guard: player may have reconnected during the async gap between the
  // setTimeout callback and this function call.
  if (isUserConnected(disconnectedPlayer)) return;

  const snap = await matchesRef.child(matchId).once("value");
  if (!snap.exists()) return;

  const match = snap.val();
  if (match.status !== "active") return;

  // Guard: re-check after the async Firebase read — the player may have
  // reconnected while we were awaiting the database.
  if (isUserConnected(disconnectedPlayer)) return;

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
  await updatePlayerStats(match.player1, match.player2, winner, match.betAmount, false, matchId);

  // 3b. Notify all clients to refresh leaderboard.
  broadcastToAll({ type: "leaderboard_update" });

  // 4. Broadcast result.
  broadcastToMatch(matchId, {
    type: "match_end",
    matchId,
    winner,
    player1: match.player1,
    player2: match.player2,
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
  // Use the last prices that were broadcast to the match room (same prices
  // clients used for their ROI display). Falls back to live prices if no
  // snapshot is available (e.g. match had no connected clients).
  const storedPrices = getMatchLastPrices(matchId);
  const prices = storedPrices ?? getLatestPrices();
  const priceMap: Record<string, number> = {
    BTC: prices.btc,
    ETH: prices.eth,
    SOL: prices.sol,
  };

  const allPositions = await getPositions(matchId);

  const p1Addr = match.player1 as string;
  const p2Addr = match.player2 as string;
  const p1Count = allPositions.filter((p) => p.playerAddress === p1Addr).length;
  const p2Count = allPositions.filter((p) => p.playerAddress === p2Addr).length;
  const openCount = allPositions.filter((p) => !p.closedAt).length;
  console.log(`[Settlement] Match ${matchId}: ${allPositions.length} positions (P1=${p1Count}, P2=${p2Count}, open=${openCount})`);

  // Close any open positions at the last-broadcast prices.
  for (const pos of allPositions) {
    if (!pos.closedAt) {
      const currentPrice = priceMap[pos.assetSymbol] ?? pos.entryPrice;
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

  // Recalculate PnL for EVERY position from entry/exit prices.
  // Never rely on stored p.pnl — it may be undefined or stale.
  const p1Pnl = allPositions
    .filter((p) => p.playerAddress === player1)
    .reduce((sum, p) => {
      const pnl = calculatePnl(p, p.exitPrice ?? p.entryPrice);
      console.log(`[Settlement]   P1 pos ${p.id}: ${p.assetSymbol} ${p.isLong ? 'LONG' : 'SHORT'} entry=${p.entryPrice} exit=${p.exitPrice} size=${p.size} lev=${p.leverage} → pnl=${pnl.toFixed(2)}`);
      return sum + pnl;
    }, 0);

  const p2Pnl = allPositions
    .filter((p) => p.playerAddress === player2)
    .reduce((sum, p) => {
      const pnl = calculatePnl(p, p.exitPrice ?? p.entryPrice);
      console.log(`[Settlement]   P2 pos ${p.id}: ${p.assetSymbol} ${p.isLong ? 'LONG' : 'SHORT'} entry=${p.entryPrice} exit=${p.exitPrice} size=${p.size} lev=${p.leverage} → pnl=${pnl.toFixed(2)}`);
      return sum + pnl;
    }, 0);

  // ROI = (finalBalance - initialBalance) / initialBalance * 100
  // Since finalBalance = DEMO_BALANCE + totalPnl, this simplifies to totalPnl / DEMO_BALANCE.
  const p1Roi = p1Pnl / DEMO_BALANCE;
  const p2Roi = p2Pnl / DEMO_BALANCE;

  console.log(`[Settlement] Match ${matchId}: P1 PnL=$${p1Pnl.toFixed(2)} ROI=${(p1Roi * 100).toFixed(2)}% | P2 PnL=$${p2Pnl.toFixed(2)} ROI=${(p2Roi * 100).toFixed(2)}%`);

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

  // 3. Update player stats + check achievements.
  await updatePlayerStats(player1, player2, winner, betAmount, isTie, matchId);

  // 3b. Notify all clients to refresh leaderboard.
  broadcastToAll({ type: "leaderboard_update" });

  // 4. Broadcast result immediately — users see it with zero delay.
  broadcastToMatch(matchId, {
    type: "match_end",
    matchId,
    winner: winner || null,
    player1,
    player2,
    p1Roi: Math.round(p1Roi * 10000) / 100,
    p2Roi: Math.round(p2Roi * 10000) / 100,
    isTie,
    isForfeit: false,
  });

  // Clean up stored price snapshot now that settlement is complete.
  clearMatchPrices(matchId);

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
  isTie: boolean,
  matchId?: string
): Promise<void> {
  const [p1, p2] = await Promise.all([getUser(player1), getUser(player2)]);
  if (!p1 || !p2) return;

  // Count trades per player from positions (if matchId provided)
  let p1TradeCount = 0;
  let p2TradeCount = 0;
  let p1WinningTrades = 0;
  let p2WinningTrades = 0;

  if (matchId) {
    const positions = await getPositions(matchId);
    for (const pos of positions) {
      if (pos.playerAddress === player1) {
        p1TradeCount++;
        if ((pos.pnl ?? 0) >= 0) p1WinningTrades++;
      } else if (pos.playerAddress === player2) {
        p2TradeCount++;
        if ((pos.pnl ?? 0) >= 0) p2WinningTrades++;
      }
    }
  }

  if (isTie) {
    const p1NewGames = (p1.gamesPlayed || 0) + 1;
    const p1NewTrades = (p1.totalTrades || 0) + p1TradeCount;
    const p2NewGames = (p2.gamesPlayed || 0) + 1;
    const p2NewTrades = (p2.totalTrades || 0) + p2TradeCount;

    await Promise.all([
      updateUser(player1, {
        ties: (p1.ties || 0) + 1,
        gamesPlayed: p1NewGames,
        currentStreak: 0,
        totalTrades: p1NewTrades,
      }),
      updateUser(player2, {
        ties: (p2.ties || 0) + 1,
        gamesPlayed: p2NewGames,
        currentStreak: 0,
        totalTrades: p2NewTrades,
      }),
    ]);

    // Check achievements for both players (tie context)
    const p1Stats = {
      wins: p1.wins || 0,
      losses: p1.losses || 0,
      ties: (p1.ties || 0) + 1,
      totalPnl: p1.totalPnl || 0,
      currentStreak: 0,
      bestStreak: p1.bestStreak || 0,
      gamesPlayed: p1NewGames,
      totalTrades: p1NewTrades,
    };
    const p2Stats = {
      wins: p2.wins || 0,
      losses: p2.losses || 0,
      ties: (p2.ties || 0) + 1,
      totalPnl: p2.totalPnl || 0,
      currentStreak: 0,
      bestStreak: p2.bestStreak || 0,
      gamesPlayed: p2NewGames,
      totalTrades: p2NewTrades,
    };

    await Promise.all([
      checkAndAwardAchievements(player1, p1Stats, p1.achievements || {}, {
        isWinner: false,
        totalTradesInMatch: p1TradeCount,
        tradeWinRate: p1TradeCount > 0 ? Math.round((p1WinningTrades / p1TradeCount) * 100) : 0,
      }),
      checkAndAwardAchievements(player2, p2Stats, p2.achievements || {}, {
        isWinner: false,
        totalTradesInMatch: p2TradeCount,
        tradeWinRate: p2TradeCount > 0 ? Math.round((p2WinningTrades / p2TradeCount) * 100) : 0,
      }),
    ]);
  } else if (winner) {
    const loser = winner === player1 ? player2 : player1;
    const winnerStats = winner === player1 ? p1 : p2;
    const loserStats = winner === player1 ? p2 : p1;
    const winnerTradeCount = winner === player1 ? p1TradeCount : p2TradeCount;
    const loserTradeCount = winner === player1 ? p2TradeCount : p1TradeCount;
    const winnerWinningTrades = winner === player1 ? p1WinningTrades : p2WinningTrades;
    const loserWinningTrades = winner === player1 ? p2WinningTrades : p1WinningTrades;

    const newCurrentStreak = (winnerStats.currentStreak || 0) + 1;
    const newBestStreak = Math.max(winnerStats.bestStreak || 0, newCurrentStreak);
    const winnerNewPnl = (winnerStats.totalPnl || 0) + betAmount * (2 * (1 - config.rakePercent) - 1);
    const loserNewPnl = (loserStats.totalPnl || 0) - betAmount;
    const winnerNewTrades = (winnerStats.totalTrades || 0) + winnerTradeCount;
    const loserNewTrades = (loserStats.totalTrades || 0) + loserTradeCount;

    await Promise.all([
      updateUser(winner, {
        wins: (winnerStats.wins || 0) + 1,
        gamesPlayed: (winnerStats.gamesPlayed || 0) + 1,
        totalPnl: winnerNewPnl,
        currentStreak: newCurrentStreak,
        bestStreak: newBestStreak,
        totalTrades: winnerNewTrades,
      }),
      updateUser(loser, {
        losses: (loserStats.losses || 0) + 1,
        gamesPlayed: (loserStats.gamesPlayed || 0) + 1,
        totalPnl: loserNewPnl,
        currentStreak: 0,
        totalTrades: loserNewTrades,
      }),
    ]);

    // Check achievements for winner
    const winnerAchStats = {
      wins: (winnerStats.wins || 0) + 1,
      losses: winnerStats.losses || 0,
      ties: winnerStats.ties || 0,
      totalPnl: winnerNewPnl,
      currentStreak: newCurrentStreak,
      bestStreak: newBestStreak,
      gamesPlayed: (winnerStats.gamesPlayed || 0) + 1,
      totalTrades: winnerNewTrades,
    };
    const winnerCtx: MatchContext = {
      isWinner: true,
      totalTradesInMatch: winnerTradeCount,
      tradeWinRate: winnerTradeCount > 0 ? Math.round((winnerWinningTrades / winnerTradeCount) * 100) : 0,
    };

    // Check achievements for loser
    const loserAchStats = {
      wins: loserStats.wins || 0,
      losses: (loserStats.losses || 0) + 1,
      ties: loserStats.ties || 0,
      totalPnl: loserNewPnl,
      currentStreak: 0,
      bestStreak: loserStats.bestStreak || 0,
      gamesPlayed: (loserStats.gamesPlayed || 0) + 1,
      totalTrades: loserNewTrades,
    };
    const loserCtx: MatchContext = {
      isWinner: false,
      totalTradesInMatch: loserTradeCount,
      tradeWinRate: loserTradeCount > 0 ? Math.round((loserWinningTrades / loserTradeCount) * 100) : 0,
    };

    await Promise.all([
      checkAndAwardAchievements(winner, winnerAchStats, winnerStats.achievements || {}, winnerCtx),
      checkAndAwardAchievements(loser, loserAchStats, loserStats.achievements || {}, loserCtx),
    ]);
  }
}
